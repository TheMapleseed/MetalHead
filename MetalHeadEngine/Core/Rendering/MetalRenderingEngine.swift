import Metal
import MetalKit
import simd
import Foundation
import QuartzCore

/// Core 3D rendering engine using Metal 4
/// Handles all 3D graphics operations with Apple Silicon optimization
@MainActor
public class MetalRenderingEngine: ObservableObject {
    // MARK: - Properties
    @Published public var fps: Int = 0
    @Published public var is3DMode: Bool = true
    @Published public var is2DMode: Bool = false
    
    // Metal objects
    public let device: MTLDevice
    private var commandQueue: MTLCommandQueue!
    private var parallelCommandQueues: [MTLCommandQueue] = [] // For parallel encoding
    private var renderPipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    private var computePipelineState: MTLComputePipelineState!
    
    // Buffers
    private var vertexBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!
    
    // Model Loading
    public let modelLoader: ModelLoader
    
    // Geometry Generation
    private let geometryShaders: GeometryShaders
    
    // Advanced Rendering
    public let computeShaderManager: ComputeShaderManager
    public let offscreenRenderer: OffscreenRenderer
    public let deferredRenderer: DeferredRenderer
    public let textureManager: TextureManager
    public let graphics2D: Graphics2D
    
    // 3D Scene
    private var camera: Camera
    private var projectionMatrix: matrix_float4x4
    private var viewMatrix: matrix_float4x4
    private var modelMatrix: matrix_float4x4
    
    // Scene objects - persistent geometry to render
    private struct SceneObject {
        let vertexBuffer: MTLBuffer
        let indexBuffer: MTLBuffer
        let indexCount: Int
        let modelMatrix: matrix_float4x4
    }
    private var sceneObjects: [SceneObject] = []
    
    // Performance tracking
    private var frameCount: Int = 0
    private var lastFPSTime: CFTimeInterval = 0
    
    // Mouse input
    private var mousePosition: SIMD2<Float> = SIMD2<Float>(0, 0)
    private var mouseDelta: SIMD2<Float> = SIMD2<Float>(0, 0)
    
    // MARK: - Initialization
    public init(device: MTLDevice) {
        self.device = device
        self.modelLoader = ModelLoader(device: device)
        self.geometryShaders = GeometryShaders(device: device)
        self.computeShaderManager = ComputeShaderManager(device: device)
        self.offscreenRenderer = OffscreenRenderer(device: device)
        self.deferredRenderer = DeferredRenderer(device: device)
        self.textureManager = TextureManager(device: device)
        self.graphics2D = Graphics2D(device: device)
        self.camera = Camera()
        self.projectionMatrix = matrix_identity_float4x4
        self.viewMatrix = matrix_identity_float4x4
        self.modelMatrix = matrix_identity_float4x4
    }
    
    // MARK: - Public Interface
    public func initialize() async throws {
        print("🚀 MetalRenderingEngine.initialize() called")
        try await setupMetal()
        print("   ✅ Metal setup complete")
        try setupBuffers()
        print("   ✅ Buffers setup complete: vertexBuffer=\(vertexBuffer?.length ?? 0), indexBuffer=\(indexBuffer?.length ?? 0)")
        try setupPipeline()
        print("   ✅ Pipeline setup complete")
        setupMatrices()
        print("   ✅ Matrices setup complete")
        
        // Initialize advanced rendering systems
        try await computeShaderManager.initialize()
        try offscreenRenderer.initialize()
        try await graphics2D.initialize()
        
        // Add default cube to scene
        print("   Adding default cube...")
        addDefaultCube()
        print("   Scene objects after initialization: \(sceneObjects.count)")
        
        print("✅ Metal Rendering Engine initialized successfully")
    }
    
    private func addDefaultCube() {
        // Use the existing cube buffers from setupBuffers
        guard let defaultVertexBuffer = vertexBuffer,
              let defaultIndexBuffer = indexBuffer else {
            print("ERROR: Cannot add default cube - buffers not initialized")
            return
        }
        
        let defaultObject = SceneObject(
            vertexBuffer: defaultVertexBuffer,
            indexBuffer: defaultIndexBuffer,
            indexCount: 36,
            modelMatrix: matrix_identity_float4x4
        )
        sceneObjects.append(defaultObject)
        print("Default cube added to scene: vertexBuffer=\(defaultVertexBuffer.length) bytes, indexBuffer=\(defaultIndexBuffer.length) bytes, indexCount=36")
    }
    
    public func render(deltaTime: CFTimeInterval, in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            if frameCount % 60 == 0 {
                print("⚠️ No drawable or render pass descriptor available")
            }
            return
        }
        
        // Log rendering activity for test verification
        if frameCount < 10 || frameCount % 60 == 0 {
            print("METRIC: render_called frameCount=\(frameCount) sceneObjects=\(sceneObjects.count) is3DMode=\(is3DMode)")
            print("🎬 MetalRenderingEngine.render() called - frameCount=\(frameCount), sceneObjects=\(sceneObjects.count), is3DMode=\(is3DMode)")
            if frameCount < 5 {
                print("   Drawable: \(drawable != nil ? "✅" : "❌"), RenderPass: \(renderPassDescriptor != nil ? "✅" : "❌")")
            }
        }
        
        // Ensure render pass descriptor is properly configured
        // Note: We modify the descriptor's properties, which is allowed even with 'let'
        if renderPassDescriptor.colorAttachments[0].loadAction == .dontCare {
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        }
        
        if renderPassDescriptor.depthAttachment.loadAction == .dontCare {
            renderPassDescriptor.depthAttachment.loadAction = .clear
            renderPassDescriptor.depthAttachment.clearDepth = 1.0
        }
        
        // Update projection matrix if view size changed
        let currentAspect = Float(view.drawableSize.width / view.drawableSize.height)
        if abs(currentAspect - (projectionMatrix.columns.1.y / projectionMatrix.columns.0.x)) > 0.01 {
            updateDrawableSize(view.drawableSize)
        }
        
        updatePerformanceMetrics(deltaTime: deltaTime)
        updateCamera(deltaTime: deltaTime)
        updateUniforms()
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            if frameCount % 60 == 0 {
                print("❌ Failed to create command buffer")
            }
            return
        }
        
        if is3DMode {
            // Dynamically choose parallel or single-threaded rendering based on scene complexity
            // Use parallel rendering when we have enough objects to benefit from GPU core scaling
            let objectCount = sceneObjects.count
            // Use parallel rendering when we have enough objects to distribute across GPU cores
            // Minimum threshold: enough objects to keep multiple GPU cores busy
            let minObjectsForParallel = max(10, parallelCommandQueues.count * 2)
            
            if objectCount >= minObjectsForParallel && !parallelCommandQueues.isEmpty {
                render3DParallelGPU(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor, drawable: drawable)
            } else {
                render3D(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
            }
        } else {
            // Render 2D scene using Graphics2D
            graphics2D.render(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // Log frame metrics for test verification
        if frameCount % 60 == 0 || frameCount < 10 {
            Logger.shared.logRendering("Frame \(frameCount) rendered - sceneObjects=\(sceneObjects.count), FPS=\(fps)", level: .info)
        }
    }
    
    public func updateMousePosition(_ position: SIMD2<Float>) {
        let newPosition = position
        mouseDelta = newPosition - mousePosition
        mousePosition = newPosition
    }
    
    public func handleMouseClick(at position: SIMD2<Float>) {
        print("Mouse clicked at: \(position)")
    }
    
    public func handleMouseScroll(delta: SIMD2<Float>) {
        camera.zoom(delta: delta.y)
    }
    
    public func toggle3DMode() {
        is3DMode.toggle()
        print("3D Mode: \(is3DMode ? "ON" : "OFF")")
    }
    
    public func toggle2DMode() {
        is2DMode.toggle()
        print("2D Mode: \(is2DMode ? "ON" : "OFF")")
    }
    
    public func updateDrawableSize(_ size: CGSize) {
        let aspectRatio = Float(size.width / size.height)
        projectionMatrix = matrix_perspective_right_hand(fovyRadians: Float.pi / 4, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100.0)
    }
    
    /// Load a 3D model from a file path
    public func loadModel(from url: URL) throws -> MTKMesh {
        return try modelLoader.loadModel(from: url)
    }
    
    /// Load a 3D model from bundle resources
    public func loadModel(name: String, extension ext: String = "obj") throws -> MTKMesh {
        return try modelLoader.loadModel(name: name, extension: ext)
    }
    
    /// Load a PBR material with textures
    public func loadPBRMaterial(baseColor: URL? = nil,
                               normal: URL? = nil,
                               roughness: URL? = nil,
                               metallic: URL? = nil) throws -> PBRMaterial {
        return try modelLoader.loadPBRMaterial(baseColor: baseColor, normal: normal, roughness: roughness, metallic: metallic)
    }
    
    /// Render a cube at the specified position
    public func renderCube(at position: SIMD3<Float>) {
        print("🔷 renderCube called at position: \(position)")
        print("   Current scene objects: \(sceneObjects.count)")
        
        // Create cube geometry
        let vertices = geometryShaders.createCube()
        let indices = geometryShaders.createCubeIndices()
        
        print("   Created \(vertices.count) vertices, \(indices.count) indices")
        
        // Create buffers for this cube instance
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: []),
              let indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: []) else {
            print("❌ Failed to create buffers for cube")
            return
        }
        
        print("   ✅ Buffers created: vertexBuffer=\(vertexBuffer.length) bytes, indexBuffer=\(indexBuffer.length) bytes")
        
        // Create model matrix for position
        var cubeModelMatrix = matrix_identity_float4x4
        cubeModelMatrix.columns.3 = SIMD4<Float>(position.x, position.y, position.z, 1.0)
        
        // Add to scene objects for persistent rendering
        let cubeObject = SceneObject(
            vertexBuffer: vertexBuffer,
            indexBuffer: indexBuffer,
            indexCount: indices.count,
            modelMatrix: cubeModelMatrix
        )
        sceneObjects.append(cubeObject)
        print("✅ Cube added to scene at position: \(position), total objects: \(sceneObjects.count)")
    }
    
    /// Render a sphere at the specified position with given radius
    public func renderSphere(at position: SIMD3<Float>, radius: Float) {
        // Create sphere geometry
        let (vertices, indices) = geometryShaders.createSphere(segments: 32)
        
        // Scale vertices by radius
        let scaledVertices = vertices.map { vertex in
            Vertex(position: vertex.position * radius, color: vertex.color)
        }
        
        // Create buffers for this sphere instance
        guard let vertexBuffer = device.makeBuffer(bytes: scaledVertices, length: scaledVertices.count * MemoryLayout<Vertex>.stride, options: []),
              let indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: []) else {
            print("Failed to create buffers for sphere")
            return
        }
        
        // Create model matrix for position
        var sphereModelMatrix = matrix_identity_float4x4
        sphereModelMatrix.columns.3 = SIMD4<Float>(position.x, position.y, position.z, 1.0)
        
        // Add to scene objects for persistent rendering
        let sphereObject = SceneObject(
            vertexBuffer: vertexBuffer,
            indexBuffer: indexBuffer,
            indexCount: indices.count,
            modelMatrix: sphereModelMatrix
        )
        sceneObjects.append(sphereObject)
        print("Sphere added to scene at position: \(position), radius: \(radius)")
    }
    
    // MARK: - Private Methods
    private func setupMetal() async throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw RenderingError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue
        
        // Create multiple command queues for parallel GPU execution
        // Metal will distribute work from different queues across all available GPU cores
        // Use a reasonable number of queues (4-8) to maximize GPU utilization
        // More queues = better GPU core utilization, but diminishing returns after ~8
        let queueCount = 8
        
        for _ in 0..<queueCount {
            if let queue = device.makeCommandQueue() {
                parallelCommandQueues.append(queue)
            }
        }
        print("Created \(parallelCommandQueues.count) parallel command queues for GPU core utilization")
        
        // Metal will execute command buffers from different queues in parallel
        // This allows work to be distributed across all available GPU cores
    }
    
    private func setupBuffers() throws {
        let vertices: [Vertex] = [
            Vertex(position: SIMD3<Float>(-1, -1,  1), color: SIMD4<Float>(1, 0, 0, 1)),
            Vertex(position: SIMD3<Float>( 1, -1,  1), color: SIMD4<Float>(0, 1, 0, 1)),
            Vertex(position: SIMD3<Float>( 1,  1,  1), color: SIMD4<Float>(0, 0, 1, 1)),
            Vertex(position: SIMD3<Float>(-1,  1,  1), color: SIMD4<Float>(1, 1, 0, 1)),
            Vertex(position: SIMD3<Float>(-1, -1, -1), color: SIMD4<Float>(1, 0, 1, 1)),
            Vertex(position: SIMD3<Float>( 1, -1, -1), color: SIMD4<Float>(0, 1, 1, 1)),
            Vertex(position: SIMD3<Float>( 1,  1, -1), color: SIMD4<Float>(1, 1, 1, 1)),
            Vertex(position: SIMD3<Float>(-1,  1, -1), color: SIMD4<Float>(0.5, 0.5, 0.5, 1))
        ]
        
        let indices: [UInt16] = [
            0, 1, 2, 2, 3, 0, 4, 5, 6, 6, 7, 4,
            7, 3, 0, 0, 4, 7, 1, 5, 6, 6, 2, 1,
            3, 2, 6, 6, 7, 3, 0, 1, 5, 5, 4, 0
        ]
        
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: []) else {
            throw RenderingError.bufferCreationFailed
        }
        self.vertexBuffer = vertexBuffer
        
        guard let indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: []) else {
            throw RenderingError.bufferCreationFailed
        }
        self.indexBuffer = indexBuffer
        
        // Metal requires constant buffers to be aligned to 256 bytes
        let uniformSize = MemoryLayout<Uniforms>.stride
        let alignedSize = (uniformSize + 255) & ~255  // Round up to 256-byte boundary
        guard let uniformBuffer = device.makeBuffer(length: alignedSize, options: []) else {
            throw RenderingError.bufferCreationFailed
        }
        self.uniformBuffer = uniformBuffer
    }
    
    private func setupPipeline() throws {
        // Load Metal library from framework bundle
        // makeDefaultLibrary() searches main bundle, but we're in a framework
        let frameworkBundle = Bundle(for: type(of: self))
        let library: MTLLibrary
        
        if let metalLibURL = frameworkBundle.url(forResource: "default", withExtension: "metallib") {
            // Load from framework bundle
            library = try device.makeLibrary(URL: metalLibURL)
        } else if let defaultLibrary = device.makeDefaultLibrary() {
            // Fall back to default (searches main bundle)
            library = defaultLibrary
        } else {
            print("❌ ERROR: Failed to create Metal library")
            print("   Framework bundle: \(frameworkBundle.bundlePath)")
            print("   Main bundle: \(Bundle.main.bundlePath)")
            print("   Device: \(device.name)")
            throw RenderingError.libraryCreationFailed
        }
        
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.rasterSampleCount = 4
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            self.renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            throw RenderingError.pipelineCreationFailed
        }
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        
        guard let depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor) else {
            throw RenderingError.depthStencilCreationFailed
        }
        self.depthStencilState = depthStencilState
    }
    
    private func setupMatrices() {
        // Default aspect ratio, will be updated when view size is known
        let aspectRatio: Float = 16.0 / 9.0
        projectionMatrix = matrix_perspective_right_hand(fovyRadians: Float.pi / 4, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100.0)
        viewMatrix = camera.viewMatrix
        modelMatrix = matrix_identity_float4x4
        
        print("Camera initialized: position=\(camera.position), rotation=\(camera.rotation)")
        print("Projection matrix initialized with aspect ratio: \(aspectRatio)")
    }
    
    private func updateCamera(deltaTime: CFTimeInterval) {
        camera.update(deltaTime: deltaTime, mouseDelta: mouseDelta)
        viewMatrix = camera.viewMatrix
    }
    
    private func updateUniforms() {
        // Base uniforms (view and projection are shared, model matrix is per-object)
        let baseUniforms = Uniforms(
            modelMatrix: matrix_identity_float4x4, // Not used, model matrix passed separately
            viewMatrix: viewMatrix,
            projectionMatrix: projectionMatrix,
            time: Float(CACurrentMediaTime())
        )
        
        let uniformPointer = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        uniformPointer.pointee = baseUniforms
    }
    
    private func render3DParallelGPU(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor, drawable: CAMetalDrawable) {
        // GPU-core scaling: Use parallel render encoder to distribute work across all GPU cores
        // Metal automatically executes encoded commands in parallel across available GPU compute units
        guard let parallelEncoder = commandBuffer.makeParallelRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            // Fallback to regular rendering if parallel encoder creation fails
            render3D(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
            return
        }
        
        guard let pipelineState = renderPipelineState else {
            print("❌ ERROR: Render pipeline state is nil!")
            parallelEncoder.endEncoding()
            return
        }
        
        // Update base uniforms once
        updateUniforms()
        
        // Scale encoding threads based on available parallel command queues (GPU parallelism)
        // More queues = more GPU cores available = more parallel encoding threads
        let objectCount = sceneObjects.count
        let queueCount = parallelCommandQueues.count
        
        // Use number of GPU queues to determine optimal encoding thread count
        // Each queue can execute work on different GPU cores in parallel
        let encodingThreadCount = min(max(1, queueCount), 8) // Match queue count, cap at 8
        let objectsPerThread = max(1, (objectCount + encodingThreadCount - 1) / encodingThreadCount)
        
        // Shared state for all threads
        let viewport = MTLViewport(
            originX: 0, originY: 0,
            width: Double(renderPassDescriptor.colorAttachments[0].texture?.width ?? 800),
            height: Double(renderPassDescriptor.colorAttachments[0].texture?.height ?? 600),
            znear: 0.0, zfar: 1.0
        )
        
        // Multi-threaded encoding: Each thread encodes a subset of objects
        // Metal will distribute the encoded work across all available GPU cores
        let encodingGroup = DispatchGroup()
        let encodingQueue = DispatchQueue(label: "com.metalhead.gpuParallelEncoding", attributes: .concurrent)
        
        // Split work across encoding threads - each thread encodes for different GPU cores
        for threadIndex in 0..<encodingThreadCount {
            let startIndex = threadIndex * objectsPerThread
            let endIndex = min(startIndex + objectsPerThread, objectCount)
            
            guard startIndex < objectCount else { break }
            
            encodingGroup.enter()
            encodingQueue.async { [weak self] in
                defer { encodingGroup.leave() }
                
                guard let self = self else { return }
                
                // Each thread gets its own encoder - Metal distributes these across GPU cores
                guard let renderEncoder = parallelEncoder.makeRenderCommandEncoder() else {
                    return
                }
                
                // Configure encoder with shared state
                renderEncoder.setRenderPipelineState(pipelineState)
                renderEncoder.setDepthStencilState(self.depthStencilState)
                renderEncoder.setViewport(viewport)
                renderEncoder.setVertexBuffer(self.uniformBuffer, offset: 0, index: 1)
                
                // Encode objects assigned to this thread
                // Metal will execute these commands in parallel across GPU cores
                for objectIndex in startIndex..<endIndex {
                    guard objectIndex < self.sceneObjects.count else { break }
                    let object = self.sceneObjects[objectIndex]
                    
                    renderEncoder.setVertexBuffer(object.vertexBuffer, offset: 0, index: 0)
                    
                    var modelMatrix = object.modelMatrix
                    renderEncoder.setVertexBytes(&modelMatrix, length: MemoryLayout<matrix_float4x4>.stride, index: 2)
                    
                    renderEncoder.drawIndexedPrimitives(
                        type: .triangle,
                        indexCount: object.indexCount,
                        indexType: .uint16,
                        indexBuffer: object.indexBuffer,
                        indexBufferOffset: 0
                    )
                }
                
                renderEncoder.endEncoding()
            }
        }
        
        // Wait for all encoding threads to complete
        encodingGroup.wait()
        
        // End the parallel encoder - Metal will execute all encoded work across GPU cores
        parallelEncoder.endEncoding()
        
        // Additionally, use parallel command queues for any compute work that can run concurrently
        // This maximizes GPU core utilization by running compute and render work in parallel
        if !parallelCommandQueues.isEmpty && objectCount > 20 {
            // For large scenes, we can also dispatch compute work (e.g., culling, LOD) in parallel
            // This uses additional GPU cores while rendering is happening
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Future: Add compute passes (frustum culling, LOD selection) using parallel queues
                // These would execute concurrently with rendering on different GPU cores
            }
        }
    }
    
    private func render3D(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("❌ ERROR: Failed to create render command encoder")
            return
        }
        
        guard let pipelineState = renderPipelineState else {
            print("❌ ERROR: Render pipeline state is nil!")
            renderEncoder.endEncoding()
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        // Debug: Verify pipeline is set
        if frameCount < 5 {
            print("   🔗 Pipeline state set: ✅, Depth stencil: ✅")
        }
        
        // Set viewport and scissor rect
        let viewport = MTLViewport(originX: 0, originY: 0, width: Double(renderPassDescriptor.colorAttachments[0].texture?.width ?? 800), height: Double(renderPassDescriptor.colorAttachments[0].texture?.height ?? 600), znear: 0.0, zfar: 1.0)
        renderEncoder.setViewport(viewport)
        
        // Update base uniforms (view and projection) once
        updateUniforms()
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        
        // Debug: Print uniform values on first frame
        if frameCount == 0 {
            let viewPos = viewMatrix.columns.3
            print("   📐 View matrix translation: (\(viewPos.x), \(viewPos.y), \(viewPos.z))")
            print("   📐 Projection matrix: near=0.1, far=100.0, fov=45°")
        }
        
        // Ensure we have at least the default cube
        if sceneObjects.isEmpty {
            addDefaultCube()
            print("Added default cube to scene (sceneObjects was empty)")
        }
        
        // Debug: Print scene object count and camera info every second
        if frameCount % 60 == 0 {
            print("🎨 Rendering \(sceneObjects.count) scene objects")
            print("   Camera position: \(camera.position), rotation: \(camera.rotation)")
            let viewPos = viewMatrix.columns.3
            print("   View matrix translation: (\(viewPos.x), \(viewPos.y), \(viewPos.z))")
            print("   Projection matrix scale: x=\(projectionMatrix.columns.0.x), y=\(projectionMatrix.columns.1.y)")
            print("   Command buffer created: ✅")
            print("   Render encoder created: ✅")
            print("   Pipeline state set: ✅")
        }
        
        // CRITICAL: If no scene objects, add default cube immediately
        if sceneObjects.isEmpty {
            print("⚠️ No scene objects! Adding default cube...")
            addDefaultCube()
            // If still empty after trying to add, something is wrong
            if sceneObjects.isEmpty {
                print("❌ CRITICAL: Failed to add default cube - buffers may not be initialized!")
                renderEncoder.endEncoding()
                return
            }
        }
        
        // Render all scene objects
        for (index, object) in sceneObjects.enumerated() {
            // Set vertex buffer for this object
            renderEncoder.setVertexBuffer(object.vertexBuffer, offset: 0, index: 0)
            
            // Set model matrix per-object using setVertexBytes (avoids buffer conflicts)
            var modelMatrix = object.modelMatrix
            renderEncoder.setVertexBytes(&modelMatrix, length: MemoryLayout<matrix_float4x4>.stride, index: 2)
            
            // Draw the object
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: object.indexCount,
                indexType: .uint16,
                indexBuffer: object.indexBuffer,
                indexBufferOffset: 0
            )
            
            // Debug first object every frame for first 10 frames
            if index == 0 && frameCount < 10 {
                let pos = modelMatrix.columns.3
                print("   ✅ Drew object 0: indexCount=\(object.indexCount), position=(\(pos.x), \(pos.y), \(pos.z))")
            }
        }
        
        // Debug: Log if we actually drew anything
        if frameCount % 60 == 0 && !sceneObjects.isEmpty {
            print("   ✅ Completed rendering \(sceneObjects.count) objects")
        }
        
        renderEncoder.endEncoding()
    }
    
    private func updatePerformanceMetrics(deltaTime: CFTimeInterval) {
        frameCount += 1
        lastFPSTime += deltaTime
        
        if lastFPSTime >= 1.0 {
            fps = frameCount
            frameCount = 0
            lastFPSTime = 0
        }
    }
}

// MARK: - Data Structures
public struct Vertex: Sendable {
    public var position: SIMD3<Float>
    public var color: SIMD4<Float>
    
    public init(position: SIMD3<Float>, color: SIMD4<Float>) {
        self.position = position
        self.color = color
    }
}

public struct Uniforms: Sendable {
    public var modelMatrix: matrix_float4x4
    public var viewMatrix: matrix_float4x4
    public var projectionMatrix: matrix_float4x4
    public var time: Float
    
    public init(modelMatrix: matrix_float4x4, viewMatrix: matrix_float4x4, projectionMatrix: matrix_float4x4, time: Float) {
        self.modelMatrix = modelMatrix
        self.viewMatrix = viewMatrix
        self.projectionMatrix = projectionMatrix
        self.time = time
    }
}

// MARK: - Camera
class Camera {
    var position: SIMD3<Float> = SIMD3<Float>(0, 0, 5)
    var rotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var fov: Float = 45.0
    var nearPlane: Float = 0.1
    var farPlane: Float = 100.0
    
    var viewMatrix: matrix_float4x4 {
        // View matrix transforms world space to view space
        // First rotate the world by negative rotation (inverse rotation)
        let invRotationMatrix = matrix_multiply(
            matrix_multiply(
                matrix_rotate_z(-rotation.z),
                matrix_rotate_y(-rotation.y)
            ),
            matrix_rotate_x(-rotation.x)
        )
        
        // Then translate the world by negative position (inverse translation)
        let invTranslationMatrix = matrix_translate(-position)
        
        // Combine: first translate, then rotate
        return matrix_multiply(invRotationMatrix, invTranslationMatrix)
    }
    
    func update(deltaTime: CFTimeInterval, mouseDelta: SIMD2<Float>) {
        rotation.y += mouseDelta.x * 0.01
        rotation.x += mouseDelta.y * 0.01
        rotation.x = max(-Float.pi/2, min(Float.pi/2, rotation.x))
    }
    
    func zoom(delta: Float) {
        position.z += delta * 0.1
        position.z = max(1.0, min(20.0, position.z))
    }
}

// MARK: - Matrix Utilities
func matrix_perspective_right_hand(fovyRadians: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let yScale = 1 / tan(fovyRadians * 0.5)
    let xScale = yScale / aspectRatio
    let zRange = farZ - nearZ
    let zScale = -(farZ + nearZ) / zRange
    let wzScale = -2 * farZ * nearZ / zRange
    
    var result = matrix_identity_float4x4
    result.columns.0 = SIMD4<Float>(xScale, 0, 0, 0)
    result.columns.1 = SIMD4<Float>(0, yScale, 0, 0)
    result.columns.2 = SIMD4<Float>(0, 0, zScale, -1)
    result.columns.3 = SIMD4<Float>(0, 0, wzScale, 0)
    return result
}

func matrix_rotate_x(_ angle: Float) -> matrix_float4x4 {
    let c = cos(angle)
    let s = sin(angle)
    
    var result = matrix_identity_float4x4
    result.columns.1 = SIMD4<Float>(0, c, s, 0)
    result.columns.2 = SIMD4<Float>(0, -s, c, 0)
    return result
}

func matrix_rotate_y(_ angle: Float) -> matrix_float4x4 {
    let c = cos(angle)
    let s = sin(angle)
    
    var result = matrix_identity_float4x4
    result.columns.0 = SIMD4<Float>(c, 0, -s, 0)
    result.columns.2 = SIMD4<Float>(s, 0, c, 0)
    return result
}

func matrix_rotate_z(_ angle: Float) -> matrix_float4x4 {
    let c = cos(angle)
    let s = sin(angle)
    
    var result = matrix_identity_float4x4
    result.columns.0 = SIMD4<Float>(c, s, 0, 0)
    result.columns.1 = SIMD4<Float>(-s, c, 0, 0)
    return result
}

func matrix_translate(_ translation: SIMD3<Float>) -> matrix_float4x4 {
    var result = matrix_identity_float4x4
    result.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)
    return result
}

// MARK: - Errors
public enum RenderingError: Error, Sendable {
    case commandQueueCreationFailed
    case bufferCreationFailed
    case libraryCreationFailed
    case pipelineCreationFailed
    case depthStencilCreationFailed
}
