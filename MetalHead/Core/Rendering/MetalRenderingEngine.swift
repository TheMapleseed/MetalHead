import Metal
import MetalKit
import simd
import Foundation

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
    
    // Advanced Rendering
    public let computeShaderManager: ComputeShaderManager
    public let offscreenRenderer: OffscreenRenderer
    public let deferredRenderer: DeferredRenderer
    public let textureManager: TextureManager
    
    // 3D Scene
    private var camera: Camera
    private var projectionMatrix: matrix_float4x4
    private var viewMatrix: matrix_float4x4
    private var modelMatrix: matrix_float4x4
    
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
        self.computeShaderManager = ComputeShaderManager(device: device)
        self.offscreenRenderer = OffscreenRenderer(device: device)
        self.deferredRenderer = DeferredRenderer(device: device)
        self.textureManager = TextureManager(device: device)
        self.camera = Camera()
        self.projectionMatrix = matrix_identity_float4x4
        self.viewMatrix = matrix_identity_float4x4
        self.modelMatrix = matrix_identity_float4x4
    }
    
    // MARK: - Public Interface
    public func initialize() async throws {
        try await setupMetal()
        try setupBuffers()
        try setupPipeline()
        setupMatrices()
        
        // Initialize advanced rendering systems
        try computeShaderManager.initialize()
        try offscreenRenderer.initialize()
        
        print("Metal Rendering Engine initialized successfully")
    }
    
    public func render(deltaTime: CFTimeInterval, in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        
        updatePerformanceMetrics(deltaTime: deltaTime)
        updateCamera(deltaTime: deltaTime)
        updateUniforms()
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        if is3DMode {
            // Use parallel rendering for better performance
            render3DParallel(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
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
    
    // MARK: - Private Methods
    private func setupMetal() async throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw RenderingError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue
        
        // Create parallel command queues for concurrent encoding
        for _ in 0..<3 {
            if let queue = device.makeCommandQueue() {
                parallelCommandQueues.append(queue)
            }
        }
        print("Created \(parallelCommandQueues.count) parallel command queues")
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
        
        guard let uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: []) else {
            throw RenderingError.bufferCreationFailed
        }
        self.uniformBuffer = uniformBuffer
    }
    
    private func setupPipeline() throws {
        guard let library = device.makeDefaultLibrary() else {
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
        let aspectRatio: Float = 16.0 / 9.0
        projectionMatrix = matrix_perspective_right_hand(fovyRadians: Float.pi / 4, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100.0)
        viewMatrix = camera.viewMatrix
        modelMatrix = matrix_identity_float4x4
    }
    
    private func updateCamera(deltaTime: CFTimeInterval) {
        camera.update(deltaTime: deltaTime, mouseDelta: mouseDelta)
        viewMatrix = camera.viewMatrix
    }
    
    private func updateUniforms() {
        let uniforms = Uniforms(
            modelMatrix: modelMatrix,
            viewMatrix: viewMatrix,
            projectionMatrix: projectionMatrix,
            time: Float(CACurrentMediaTime())
        )
        
        let uniformPointer = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        uniformPointer.pointee = uniforms
    }
    
    private func render3DParallel(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        // Create parallel render command encoder to utilize all CPU cores
        guard let parallelEncoder = commandBuffer.makeParallelRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            // Fallback if parallel rendering not available
            render3D(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
            return
        }
        
        // Determine number of sub-encoders based on CPU cores
        let cpuCount = ProcessInfo.processInfo.processorCount
        let threadCount = min(cpuCount, 8) // Limit to 8 threads for optimal performance
        
        print("Parallel rendering across \(threadCount) CPU cores (total: \(cpuCount) cores available)")
        
        // Encode rendering commands concurrently across all CPU cores
        let concurrentQueue = DispatchQueue(label: "com.metalhead.parallel", attributes: .concurrent)
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "parallelEncoding", attributes: .concurrent)
        
        // Split work across multiple threads
        for i in 0..<threadCount {
            group.enter()
            queue.async { [weak self] in
                defer { group.leave() }
                
                guard let self = self else { return }
                
                // Get or create sub-encoder for this thread
                if let subEncoder = parallelEncoder.makeRenderCommandEncoder() {
                    subEncoder.setRenderPipelineState(self.renderPipelineState)
                    subEncoder.setDepthStencilState(self.depthStencilState)
                    subEncoder.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
                    subEncoder.setVertexBuffer(self.uniformBuffer, offset: 0, index: 1)
                    
                    // Each thread renders a portion of the geometry
                    let triangleCount = 36
                    let trianglesPerThread = triangleCount / threadCount
                    let offset = (i * trianglesPerThread) * MemoryLayout<UInt16>.size
                    let count = (i == threadCount - 1) ? (triangleCount - (trianglesPerThread * i)) : trianglesPerThread
                    
                    if count > 0 {
                        subEncoder.drawIndexedPrimitives(type: .triangle,
                                                        indexCount: count,
                                                        indexType: .uint16,
                                                        indexBuffer: self.indexBuffer,
                                                        indexBufferOffset: offset)
                    }
                    
                    subEncoder.endEncoding()
                }
            }
        }
        
        // Wait for all threads to complete encoding
        group.wait()
        
        // End the parallel encoder
        parallelEncoder.endEncoding()
    }
    
    private func render3D(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: 36, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
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
public struct Vertex {
    public var position: SIMD3<Float>
    public var color: SIMD4<Float>
    
    public init(position: SIMD3<Float>, color: SIMD4<Float>) {
        self.position = position
        self.color = color
    }
}

public struct Uniforms {
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
        let rotationMatrix = matrix_multiply(
            matrix_multiply(
                matrix_rotate_x(rotation.x),
                matrix_rotate_y(rotation.y)
            ),
            matrix_rotate_z(rotation.z)
        )
        
        let translationMatrix = matrix_translate(position)
        return matrix_multiply(rotationMatrix, translationMatrix)
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
public enum RenderingError: Error {
    case commandQueueCreationFailed
    case bufferCreationFailed
    case libraryCreationFailed
    case pipelineCreationFailed
    case depthStencilCreationFailed
}
