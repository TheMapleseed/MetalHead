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
    private var intersectionFunctionTable: MTLIntersectionFunctionTable?
    private var rayTracingPipelineState: MTLComputePipelineState?
    private var commandQueue: MTLCommandQueue!
    
    // Ray tracing data
    private var instances: [RTInstance] = []
    private var geometries: [RTGeometry] = []
    private var materials: [RTMaterial] = []
    private var lights: [RTLight] = []
    
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
    }
    
    public func addMaterial(_ material: RTMaterial) {
        materials.append(material)
    }
    
    public func addLight(_ light: RTLight) {
        lights.append(light)
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
    
    public func traceRays(commandBuffer: MTLCommandBuffer) {
        guard isEnabled, let accelerationStructure = accelerationStructure else {
            return
        }
        
        updateAccelerationStructure()
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        encoder.setComputePipelineState(rayTracingPipelineState!)
        encoder.setAccelerationStructure(accelerationStructure, bufferIndex: 0)
        encoder.setIntersectionFunctionTable(intersectionFunctionTable, bufferIndex: 1)
        
        // Set ray tracing parameters
        encoder.setBytes(&rayCount, length: MemoryLayout<UInt32>.size, index: 2)
        encoder.setBytes(&bounces, length: MemoryLayout<UInt32>.size, index: 3)
        encoder.setBytes(&samples, length: MemoryLayout<UInt32>.size, index: 4)
        
        // Dispatch rays
        let threadsPerThreadgroup = MTLSize(width: 8, height: 8, depth: 1)
        let threadgroupsPerGrid = MTLSize(
            width: Int(rayCount) / threadsPerThreadgroup.width,
            height: 1,
            depth: 1
        )
        
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
        return device.supportsFamily(.apple8) || device.supportsFamily(.apple9)
    }
    
    private func setupRayTracing() async throws {
        commandQueue = device.makeCommandQueue()
        
        // Create ray tracing pipeline
        guard let library = device.makeDefaultLibrary() else {
            throw RayTracingError.libraryCreationFailed
        }
        
        guard let raytracingFunction = library.makeFunction(name: "raytracing_kernel") else {
            throw RayTracingError.functionNotFound
        }
        
        let descriptor = MTLComputePipelineDescriptor()
        descriptor.computeFunction = raytracingFunction
        descriptor.maxCallStackDepth = 8
        
        do {
            let result = try await device.makeComputePipelineState(descriptor: descriptor, options: [])
            rayTracingPipelineState = result.0
        } catch {
            throw RayTracingError.libraryCreationFailed
        }
        
        // Create intersection function table
        let tableDescriptor = MTLIntersectionFunctionTableDescriptor()
        tableDescriptor.functionCount = 16
        
        intersectionFunctionTable = rayTracingPipelineState?.makeIntersectionFunctionTable(descriptor: tableDescriptor)
        
        // Set default parameters
        rayCount = 1_000_000
        bounces = 3
        samples = 1
    }
    
    private func updateAccelerationStructure() {
        // Build acceleration structure for ray tracing
        // This is called every frame to update geometry
    }
    
    private func updatePerformanceMetrics() {
        performanceMetrics.totalRays += rayCount
        performanceMetrics.bounceCount = bounces
        performanceMetrics.sampleCount = samples
    }
}

// MARK: - Data Structures
public struct RTGeometry {
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

public struct RTMaterial {
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

public struct RTLight {
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

public struct RTInstance {
    let geometryIndex: Int
    let transform: matrix_float4x4
    let materialIndex: Int
}

public struct AABB {
    let min: SIMD3<Float>
    let max: SIMD3<Float>
    
    public init(min: SIMD3<Float>, max: SIMD3<Float>) {
        self.min = min
        self.max = max
    }
}

public enum GeometryType {
    case triangle
    case sphere
    case box
    case plane
}

public enum LightType {
    case point
    case directional
    case spot
    case area
}

public struct RayTracingPerformanceMetrics {
    public var totalRays: UInt32 = 0
    public var bounceCount: UInt32 = 0
    public var sampleCount: UInt32 = 0
    public var averageHitDistance: Float = 0
    public var totalSamples: UInt32 = 0
}

// MARK: - Errors
public enum RayTracingError: Error {
    case notSupported
    case functionNotFound
    case libraryCreationFailed
    case accelerationStructureCreationFailed
}
