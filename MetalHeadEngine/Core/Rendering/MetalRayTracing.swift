import Metal
import MetalKit
import simd

/// Metal 4 Ray Tracing Engine with hardware acceleration
/// Supports: M2 Ultra, M3 Pro/Max/Ultra, M4 chips
@MainActor
public class MetalRayTracingEngine: ObservableObject {
    // MARK: - Properties
    @Published public var isEnabled: Bool = false
    @Published public var rayCount: UInt32 = 0
    @Published public var bounces: UInt32 = 0
    @Published public var samples: UInt32 = 0
    
    // Metal objects
    public let device: MTLDevice
    private var accelerationStructure: MTLAccelerationStructure?
    private var primitiveAccelerationStructure: MTLAccelerationStructure?
    private var instanceAccelerationStructure: MTLAccelerationStructure?
    private var intersectionFunctionTable: MTLIntersectionFunctionTable?
    private var rayTracingPipelineState: MTLComputePipelineState?
    private var commandQueue: MTLCommandQueue!
    
    // Ray tracing data
    private var instances: [RTInstance] = []
    private var geometries: [RTGeometry] = []
    private var materials: [RTMaterial] = []
    private var lights: [RTLight] = []
    
    // Acceleration structure buffers
    private var geometryBuffers: [MTLBuffer] = []
    private var indexBuffers: [MTLBuffer] = []
    private var instanceBuffer: MTLBuffer?
    private var accelerationStructureNeedsUpdate: Bool = true
    
    // Performance tracking
    private var lastRayCount: UInt32 = 0
    private var performanceMetrics: RayTracingPerformanceMetrics = RayTracingPerformanceMetrics()
    
    // MARK: - Initialization
    public init(device: MTLDevice) {
        self.device = device
    }
    
    // MARK: - Public Interface
    public func initialize() async throws {
        // Check for ray tracing support
        guard supportsRayTracing() else {
            throw RayTracingError.notSupported
        }
        
        try await setupRayTracing()
        print("Metal Ray Tracing Engine initialized with hardware acceleration")
    }
    
    public func addGeometry(_ geometry: RTGeometry) {
        geometries.append(geometry)
        accelerationStructureNeedsUpdate = true
    }
    
    public func addMaterial(_ material: RTMaterial) {
        materials.append(material)
    }
    
    public func addLight(_ light: RTLight) {
        lights.append(light)
    }
    
    public func addInstance(_ instance: RTInstance) {
        instances.append(instance)
        accelerationStructureNeedsUpdate = true
    }
    
    public func setRayCount(_ count: UInt32) {
        rayCount = count
    }
    
    public func setBounceCount(_ count: UInt32) {
        bounces = count
    }
    
    public func setSampleCount(_ count: UInt32) {
        samples = count
    }
    
    public func traceRays(commandBuffer: MTLCommandBuffer) async throws {
        guard isEnabled else {
            return
        }
        
        guard let accelerationStructure = accelerationStructure else {
            throw RayTracingError.accelerationStructureCreationFailed
        }
        
        guard let pipelineState = rayTracingPipelineState else {
            throw RayTracingError.libraryCreationFailed
        }
        
        // Update acceleration structure if needed
        if accelerationStructureNeedsUpdate {
            try await buildAccelerationStructure()
            accelerationStructureNeedsUpdate = false
        }
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RayTracingError.encoderCreationFailed
        }
        
        encoder.setComputePipelineState(pipelineState)
        encoder.setAccelerationStructure(accelerationStructure, bufferIndex: 0)
        
        if let intersectionTable = intersectionFunctionTable {
            encoder.setIntersectionFunctionTable(intersectionTable, bufferIndex: 1)
        }
        
        // Set ray tracing parameters
        encoder.setBytes(&rayCount, length: MemoryLayout<UInt32>.size, index: 2)
        encoder.setBytes(&bounces, length: MemoryLayout<UInt32>.size, index: 3)
        encoder.setBytes(&samples, length: MemoryLayout<UInt32>.size, index: 4)
        
        // Dispatch rays - use proper threadgroup configuration
        let threadsPerThreadgroup = MTLSize(width: 8, height: 8, depth: 1)
        let width = max(1, Int(rayCount) / threadsPerThreadgroup.width)
        let threadgroupsPerGrid = MTLSize(width: width, height: 1, depth: 1)
        
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        
        updatePerformanceMetrics()
    }
    
    public func getPerformanceMetrics() -> RayTracingPerformanceMetrics {
        return performanceMetrics
    }
    
    // MARK: - Private Methods
    private func supportsRayTracing() -> Bool {
        // Check for Metal 4 ray tracing support
        // Apple8 = M2 Ultra, Apple9 = M3 Pro/Max/Ultra, Apple10 = M4 and future
        return device.supportsFamily(.apple8) || device.supportsFamily(.apple9) || device.supportsFamily(.apple10)
    }
    
    private func setupRayTracing() async throws {
        guard let queue = device.makeCommandQueue() else {
            throw RayTracingError.commandQueueCreationFailed
        }
        commandQueue = queue
        
        // Create ray tracing pipeline
        // Load Metal library from framework bundle
        let frameworkBundle = Bundle(for: type(of: self))
        let library: MTLLibrary
        
        if let metalLibURL = frameworkBundle.url(forResource: "default", withExtension: "metallib") {
            library = try device.makeLibrary(URL: metalLibURL)
        } else if let defaultLibrary = device.makeDefaultLibrary() {
            library = defaultLibrary
        } else {
            throw RayTracingError.libraryCreationFailed
        }
        
        if let raytracingFunction = library.makeFunction(name: "ray_generation") {
            // Use proper ray tracing pipeline
            let descriptor = MTLComputePipelineDescriptor()
            descriptor.computeFunction = raytracingFunction
            descriptor.maxCallStackDepth = 8
            
            // Link intersection functions if available
            if let triangleIntersection = library.makeFunction(name: "intersect_triangle"),
               let sphereIntersection = library.makeFunction(name: "intersect_sphere") {
                let linkedFunctions = MTLLinkedFunctions()
                linkedFunctions.functions = [triangleIntersection, sphereIntersection]
                descriptor.linkedFunctions = linkedFunctions
            }
            
            do {
                let result = try await device.makeComputePipelineState(descriptor: descriptor, options: [])
                rayTracingPipelineState = result.0
            } catch {
                throw RayTracingError.libraryCreationFailed
            }
        } else {
            // Fallback to compute kernel if ray generation not available
            guard let computeFunction = library.makeFunction(name: "raytracing_kernel") else {
                throw RayTracingError.functionNotFound
            }
            
            let descriptor = MTLComputePipelineDescriptor()
            descriptor.computeFunction = computeFunction
            descriptor.maxCallStackDepth = 8
            
            do {
                let result = try await device.makeComputePipelineState(descriptor: descriptor, options: [])
                rayTracingPipelineState = result.0
            } catch {
                throw RayTracingError.libraryCreationFailed
            }
        }
        
        // Create intersection function table
        let tableDescriptor = MTLIntersectionFunctionTableDescriptor()
        // Calculate function count from available functions
        var functionCount = 0
        if let _ = library.makeFunction(name: "intersect_triangle") { functionCount += 1 }
        if let _ = library.makeFunction(name: "intersect_sphere") { functionCount += 1 }
        if let _ = library.makeFunction(name: "intersect_box") { functionCount += 1 }
        if functionCount == 0 { functionCount = 16 } // Default fallback
        
        tableDescriptor.functionCount = functionCount
        
        guard let pipelineState = rayTracingPipelineState else {
            throw RayTracingError.libraryCreationFailed
        }
        
        intersectionFunctionTable = pipelineState.makeIntersectionFunctionTable(descriptor: tableDescriptor)
        
        // Populate intersection function table
        populateIntersectionFunctionTable(library: library, pipelineState: pipelineState)
        
        // Create initial acceleration structure
        try await buildAccelerationStructure()
        
        // Set default parameters
        rayCount = 1_000_000
        bounces = 3
        samples = 1
    }
    
    private func populateIntersectionFunctionTable(library: MTLLibrary, pipelineState: MTLComputePipelineState) {
        guard let table = intersectionFunctionTable else { return }
        
        var index = 0
        
        if let triangleFunction = library.makeFunction(name: "intersect_triangle"),
           let triangleHandle = pipelineState.functionHandle(function: triangleFunction) {
            table.setFunction(triangleHandle, index: index)
            index += 1
        }
        
        if let sphereFunction = library.makeFunction(name: "intersect_sphere"),
           let sphereHandle = pipelineState.functionHandle(function: sphereFunction) {
            table.setFunction(sphereHandle, index: index)
            index += 1
        }
        
        if let boxFunction = library.makeFunction(name: "intersect_box"),
           let boxHandle = pipelineState.functionHandle(function: boxFunction) {
            table.setFunction(boxHandle, index: index)
            index += 1
        }
    }
    
    private func buildAccelerationStructure() async throws {
        if geometries.isEmpty {
            // Create a default geometry if none exists
            let defaultBounds = AABB(min: SIMD3<Float>(-1, -1, -1), max: SIMD3<Float>(1, 1, 1))
            let defaultGeometry = RTGeometry(
                type: .triangle,
                vertices: [
                    SIMD3<Float>(-1, -1, 0),
                    SIMD3<Float>(1, -1, 0),
                    SIMD3<Float>(0, 1, 0)
                ],
                indices: [0, 1, 2],
                bounds: defaultBounds
            )
            geometries.append(defaultGeometry)
        }
        
        // Build primitive acceleration structure
        try await buildPrimitiveAccelerationStructure()
        
        // Build instance acceleration structure if we have instances
        if !instances.isEmpty {
            try await buildInstanceAccelerationStructure()
            accelerationStructure = instanceAccelerationStructure
        } else {
            accelerationStructure = primitiveAccelerationStructure
        }
    }
    
    private func buildPrimitiveAccelerationStructure() async throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw RayTracingError.commandBufferCreationFailed
        }
        
        // Clear old buffers
        geometryBuffers.removeAll()
        indexBuffers.removeAll()
        
        var geometryDescriptors: [MTLAccelerationStructureTriangleGeometryDescriptor] = []
        
        // Create geometry descriptors for each geometry
        for (_, geometry) in geometries.enumerated() {
            guard geometry.type == .triangle, let indices = geometry.indices else {
                continue // Skip non-triangle geometries for now
            }
            
            // Create vertex buffer
            let vertexData = geometry.vertices.map { $0 }
            guard let vertexBuffer = device.makeBuffer(
                bytes: vertexData,
                length: vertexData.count * MemoryLayout<SIMD3<Float>>.stride,
                options: []
            ) else {
                continue
            }
            geometryBuffers.append(vertexBuffer)
            
            // Create index buffer
            guard let indexBuffer = device.makeBuffer(
                bytes: indices,
                length: indices.count * MemoryLayout<UInt32>.stride,
                options: []
            ) else {
                continue
            }
            indexBuffers.append(indexBuffer)
            
            // Create geometry descriptor
            let geometryDescriptor = MTLAccelerationStructureTriangleGeometryDescriptor()
            geometryDescriptor.vertexBuffer = vertexBuffer
            geometryDescriptor.vertexStride = MemoryLayout<SIMD3<Float>>.stride
            geometryDescriptor.indexBuffer = indexBuffer
            geometryDescriptor.indexType = .uint32
            geometryDescriptor.triangleCount = indices.count / 3
            
            geometryDescriptors.append(geometryDescriptor)
        }
        
        guard !geometryDescriptors.isEmpty else {
            throw RayTracingError.accelerationStructureCreationFailed
        }
        
        // Create primitive acceleration structure descriptor
        let primitiveDescriptor = MTLPrimitiveAccelerationStructureDescriptor()
        primitiveDescriptor.geometryDescriptors = geometryDescriptors
        
        // Query acceleration structure sizes
        let sizes = device.accelerationStructureSizes(descriptor: primitiveDescriptor)
        
        // Allocate acceleration structure
        guard let accelerationStructure = device.makeAccelerationStructure(size: sizes.accelerationStructureSize) else {
            throw RayTracingError.accelerationStructureCreationFailed
        }
        primitiveAccelerationStructure = accelerationStructure
        
        // Allocate scratch buffer
        guard let scratchBuffer = device.makeBuffer(length: sizes.buildScratchBufferSize, options: .storageModePrivate) else {
            throw RayTracingError.accelerationStructureCreationFailed
        }
        
        // Build acceleration structure
        guard let accelerationEncoder = commandBuffer.makeAccelerationStructureCommandEncoder() else {
            throw RayTracingError.encoderCreationFailed
        }
        
        accelerationEncoder.build(accelerationStructure: accelerationStructure,
                                descriptor: primitiveDescriptor,
                                scratchBuffer: scratchBuffer,
                                scratchBufferOffset: 0)
        accelerationEncoder.endEncoding()
        
        commandBuffer.commit()
        await commandBuffer.completed()
    }
    
    private func buildInstanceAccelerationStructure() async throws {
        guard let primitiveAS = primitiveAccelerationStructure else {
            throw RayTracingError.accelerationStructureCreationFailed
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw RayTracingError.commandBufferCreationFailed
        }
        
        // Create instance descriptors
        var instanceDescriptors: [MTLAccelerationStructureInstanceDescriptor] = []
        
        for instance in instances {
            var descriptor = MTLAccelerationStructureInstanceDescriptor()
            descriptor.accelerationStructureIndex = 0
            descriptor.options = .opaque
            descriptor.mask = 0xFF
            descriptor.intersectionFunctionTableOffset = UInt32(instance.materialIndex)
            
            // Set transformation matrix
            // MTLAccelerationStructureInstanceDescriptor uses column-major matrix
            var matrix = instance.transform
            withUnsafeMutablePointer(to: &descriptor.transformationMatrix) { matrixPtr in
                withUnsafePointer(to: &matrix) { transformPtr in
                    let floatPtr = UnsafeRawPointer(transformPtr).bindMemory(to: Float.self, capacity: 16)
                    matrixPtr.withMemoryRebound(to: Float.self, capacity: 16) { destPtr in
                        for i in 0..<16 {
                            destPtr[i] = floatPtr[i]
                        }
                    }
                }
            }
            
            instanceDescriptors.append(descriptor)
        }
        
        guard !instanceDescriptors.isEmpty else {
            throw RayTracingError.accelerationStructureCreationFailed
        }
        
        // Create instance buffer
        guard let instanceBuffer = device.makeBuffer(
            bytes: instanceDescriptors,
            length: instanceDescriptors.count * MemoryLayout<MTLAccelerationStructureInstanceDescriptor>.stride,
            options: []
        ) else {
            throw RayTracingError.accelerationStructureCreationFailed
        }
        self.instanceBuffer = instanceBuffer
        
        // Create instance acceleration structure descriptor
        let instanceDescriptor = MTLInstanceAccelerationStructureDescriptor()
        instanceDescriptor.instancedAccelerationStructures = [primitiveAS]
        instanceDescriptor.instanceCount = instanceDescriptors.count
        instanceDescriptor.instanceDescriptorBuffer = instanceBuffer
        
        // Query sizes
        let sizes = device.accelerationStructureSizes(descriptor: instanceDescriptor)
        
        // Allocate acceleration structure
        guard let accelerationStructure = device.makeAccelerationStructure(size: sizes.accelerationStructureSize) else {
            throw RayTracingError.accelerationStructureCreationFailed
        }
        instanceAccelerationStructure = accelerationStructure
        
        // Allocate scratch buffer
        guard let scratchBuffer = device.makeBuffer(length: sizes.buildScratchBufferSize, options: .storageModePrivate) else {
            throw RayTracingError.accelerationStructureCreationFailed
        }
        
        // Build acceleration structure
        guard let accelerationEncoder = commandBuffer.makeAccelerationStructureCommandEncoder() else {
            throw RayTracingError.encoderCreationFailed
        }
        
        accelerationEncoder.build(accelerationStructure: accelerationStructure,
                                descriptor: instanceDescriptor,
                                scratchBuffer: scratchBuffer,
                                scratchBufferOffset: 0)
        accelerationEncoder.endEncoding()
        
        commandBuffer.commit()
        await commandBuffer.completed()
    }
    
    public func markAccelerationStructureDirty() {
        accelerationStructureNeedsUpdate = true
    }
    
    private func updatePerformanceMetrics() {
        performanceMetrics.totalRays += rayCount
        performanceMetrics.bounceCount = bounces
        performanceMetrics.sampleCount = samples
    }
}

// MARK: - Data Structures
public struct RTGeometry: Sendable {
    let type: GeometryType
    let vertices: [SIMD3<Float>]
    let indices: [UInt32]?
    let bounds: AABB
    
    public init(type: GeometryType, vertices: [SIMD3<Float>], indices: [UInt32]? = nil, bounds: AABB) {
        self.type = type
        self.vertices = vertices
        self.indices = indices
        self.bounds = bounds
    }
}

public struct RTMaterial: Sendable {
    let albedo: SIMD3<Float>
    let roughness: Float
    let metallic: Float
    let emission: SIMD3<Float>
    
    public init(albedo: SIMD3<Float>, roughness: Float, metallic: Float, emission: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) {
        self.albedo = albedo
        self.roughness = roughness
        self.metallic = metallic
        self.emission = emission
    }
}

public struct RTLight: Sendable {
    let position: SIMD3<Float>
    let color: SIMD3<Float>
    let intensity: Float
    let type: LightType
    
    public init(position: SIMD3<Float>, color: SIMD3<Float>, intensity: Float, type: LightType = .point) {
        self.position = position
        self.color = color
        self.intensity = intensity
        self.type = type
    }
}

public struct RTInstance: Sendable {
    let geometryIndex: Int
    let transform: matrix_float4x4
    let materialIndex: Int
}

public struct AABB: Sendable {
    let min: SIMD3<Float>
    let max: SIMD3<Float>
    
    public init(min: SIMD3<Float>, max: SIMD3<Float>) {
        self.min = min
        self.max = max
    }
}

public enum GeometryType: Sendable {
    case triangle
    case sphere
    case box
    case plane
}

public enum LightType: Sendable {
    case point
    case directional
    case spot
    case area
}

public struct RayTracingPerformanceMetrics: Sendable {
    public var totalRays: UInt32 = 0
    public var bounceCount: UInt32 = 0
    public var sampleCount: UInt32 = 0
    public var averageHitDistance: Float = 0
    public var totalSamples: UInt32 = 0
}

// MARK: - Errors
public enum RayTracingError: Error, Sendable {
    case notSupported
    case functionNotFound
    case libraryCreationFailed
    case accelerationStructureCreationFailed
    case commandQueueCreationFailed
    case commandBufferCreationFailed
    case encoderCreationFailed
}
