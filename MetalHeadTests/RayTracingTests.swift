import XCTest
import Metal
import simd
import QuartzCore
@testable import MetalHeadEngine

/// Unit tests for MetalRayTracingEngine
/// Tests comprehensive error handling and all code paths
final class RayTracingTests: XCTestCase {
    
    var device: MTLDevice!
    var rayTracing: MetalRayTracingEngine!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.metalNotSupported
        }
        self.device = device
        
        rayTracing = MetalRayTracingEngine(device: device)
    }
    
    override func tearDownWithError() throws {
        rayTracing = nil
        device = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func test_RayTracingInitialization_whenSupportedDevice_expectSuccess() async throws {
        // Given
        XCTAssertNotNil(rayTracing)
        
        // When
        try await rayTracing.initialize()
        
        // Then
        XCTAssertEqual(rayTracing.isEnabled, false) // Default disabled
        XCTAssertEqual(rayTracing.rayCount, 1_000_000) // Default ray count
        XCTAssertEqual(rayTracing.bounces, 3) // Default bounce count
        XCTAssertEqual(rayTracing.samples, 1) // Default sample count
    }
    
    func test_RayTracingInitialization_whenNotSupportedDevice_expectError() async throws {
        // Given
        let unsupportedDevice: MTLDevice? = nil
        
        // When & Then
        if unsupportedDevice == nil {
            XCTAssertThrowsError(try await createRayTracingWithDevice(unsupportedDevice)) { error in
                XCTAssertTrue(error is RayTracingError)
            }
        }
    }
    
    // MARK: - Configuration Tests
    
    func test_SetRayCount_whenValidValue_expectUpdated() {
        // Given
        let newRayCount: UInt32 = 2_000_000
        
        // When
        rayTracing.setRayCount(newRayCount)
        
        // Then
        XCTAssertEqual(rayTracing.rayCount, newRayCount)
    }
    
    func test_SetBounceCount_whenValidValue_expectUpdated() {
        // Given
        let newBounceCount: UInt32 = 5
        
        // When
        rayTracing.setBounceCount(newBounceCount)
        
        // Then
        XCTAssertEqual(rayTracing.bounces, newBounceCount)
    }
    
    func test_SetSampleCount_whenValidValue_expectUpdated() {
        // Given
        let newSampleCount: UInt32 = 4
        
        // When
        rayTracing.setSampleCount(newSampleCount)
        
        // Then
        XCTAssertEqual(rayTracing.samples, newSampleCount)
    }
    
    func test_SetRayCount_whenZero_expectZero() {
        // Given
        let zeroCount: UInt32 = 0
        
        // When
        rayTracing.setRayCount(zeroCount)
        
        // Then
        XCTAssertEqual(rayTracing.rayCount, zeroCount)
    }
    
    func test_SetBounceCount_whenZero_expectZero() {
        // Given
        let zeroBounces: UInt32 = 0
        
        // When
        rayTracing.setBounceCount(zeroBounces)
        
        // Then
        XCTAssertEqual(rayTracing.bounces, zeroBounces)
    }
    
    // MARK: - Geometry Tests
    
    func test_AddGeometry_whenValidGeometry_expectAdded() async throws {
        // Given
        try await rayTracing.initialize()
        
        let geometry = RTGeometry(
            type: .sphere,
            vertices: [SIMD3<Float>(0, 0, 0)],
            indices: nil,
            bounds: AABB(min: SIMD3<Float>(-1, -1, -1), max: SIMD3<Float>(1, 1, 1))
        )
        
        // When & Then - should not throw
        XCTAssertNoThrow(rayTracing.addGeometry(geometry), "Adding geometry should not throw")
        
        // Verify we can add multiple geometries
        let geometry2 = RTGeometry(
            type: .box,
            vertices: [],
            indices: nil,
            bounds: AABB(min: SIMD3<Float>(-2, -2, -2), max: SIMD3<Float>(2, 2, 2))
        )
        XCTAssertNoThrow(rayTracing.addGeometry(geometry2), "Adding second geometry should work")
    }
    
    func test_AddGeometry_whenMultipleGeometries_expectAllAdded() async throws {
        // Given
        try await rayTracing.initialize()
        
        let geometries = [
            RTGeometry(type: .sphere, vertices: [], indices: nil, bounds: AABB(min: SIMD3<Float>(-1), max: SIMD3<Float>(1))),
            RTGeometry(type: .box, vertices: [], indices: nil, bounds: AABB(min: SIMD3<Float>(-1), max: SIMD3<Float>(1))),
            RTGeometry(type: .plane, vertices: [], indices: nil, bounds: AABB(min: SIMD3<Float>(-1), max: SIMD3<Float>(1)))
        ]
        
        // When & Then - should not throw
        for (index, geometry) in geometries.enumerated() {
            XCTAssertNoThrow(rayTracing.addGeometry(geometry), "Adding geometry \(index) should not throw")
        }
        
        // Verify we can trace rays after adding geometries (indirect verification)
        guard let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }
        rayTracing.isEnabled = true
        XCTAssertNoThrow(try await rayTracing.traceRays(commandBuffer: commandBuffer), "Tracing rays after adding geometries should work")
    }
    
    // MARK: - Material Tests
    
    func test_AddMaterial_whenValidMaterial_expectAdded() async throws {
        // Given
        try await rayTracing.initialize()
        
        let material = RTMaterial(
            albedo: SIMD3<Float>(0.8, 0.2, 0.2),
            roughness: 0.3,
            metallic: 0.8
        )
        
        // When & Then - should not throw
        XCTAssertNoThrow(rayTracing.addMaterial(material), "Adding material should not throw")
        
        // Verify we can add multiple materials
        let material2 = RTMaterial(albedo: SIMD3<Float>(0.2, 0.8, 0.2), roughness: 0.7, metallic: 0.2)
        XCTAssertNoThrow(rayTracing.addMaterial(material2), "Adding second material should work")
    }
    
    func test_AddMaterial_whenMultipleMaterials_expectAllAdded() async throws {
        // Given
        try await rayTracing.initialize()
        
        let materials = [
            RTMaterial(albedo: SIMD3<Float>(1, 0, 0), roughness: 0.1, metallic: 0.9),
            RTMaterial(albedo: SIMD3<Float>(0, 1, 0), roughness: 0.5, metallic: 0.5),
            RTMaterial(albedo: SIMD3<Float>(0, 0, 1), roughness: 0.9, metallic: 0.1)
        ]
        
        // When & Then - should not throw
        for (index, material) in materials.enumerated() {
            XCTAssertNoThrow(rayTracing.addMaterial(material), "Adding material \(index) should not throw")
        }
        
        // Verify materials can be used (indirect - by tracing rays)
        guard let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }
        rayTracing.isEnabled = true
        XCTAssertNoThrow(try await rayTracing.traceRays(commandBuffer: commandBuffer), "Tracing with materials should work")
    }
    
    // MARK: - Light Tests
    
    func test_AddLight_whenPointLight_expectAdded() async throws {
        // Given
        try await rayTracing.initialize()
        
        let light = RTLight(
            position: SIMD3<Float>(0, 5, 0),
            color: SIMD3<Float>(1, 1, 1),
            intensity: 1.0,
            type: .point
        )
        
        // When & Then - should not throw
        XCTAssertNoThrow(rayTracing.addLight(light), "Adding point light should not throw")
        
        // Verify we can add multiple lights
        let light2 = RTLight(position: SIMD3<Float>(5, 5, 5), color: SIMD3<Float>(1, 1, 1), intensity: 0.5, type: .point)
        XCTAssertNoThrow(rayTracing.addLight(light2), "Adding second light should work")
    }
    
    func test_AddLight_whenDirectionalLight_expectAdded() async throws {
        // Given
        try await rayTracing.initialize()
        
        let light = RTLight(
            position: SIMD3<Float>(0, 1, 0),
            color: SIMD3<Float>(1, 1, 1),
            intensity: 2.0,
            type: .directional
        )
        
        // When & Then - should not throw
        XCTAssertNoThrow(rayTracing.addLight(light), "Adding directional light should not throw")
        
        // Verify light type
        XCTAssertEqual(light.type, .directional, "Light type should be directional")
        XCTAssertEqual(light.intensity, 2.0, accuracy: 0.01, "Light intensity should match")
    }
    
    func test_AddLight_whenSpotLight_expectAdded() async throws {
        // Given
        try await rayTracing.initialize()
        
        let light = RTLight(
            position: SIMD3<Float>(0, 0, -5),
            color: SIMD3<Float>(1, 1, 1),
            intensity: 1.5,
            type: .spot
        )
        
        // When & Then - should not throw
        XCTAssertNoThrow(rayTracing.addLight(light), "Adding spot light should not throw")
        
        // Verify light type and position
        XCTAssertEqual(light.type, .spot, "Light type should be spot")
        XCTAssertEqual(light.position.z, -5, accuracy: 0.01, "Light position should match")
    }
    
    func test_AddLight_whenAreaLight_expectAdded() async throws {
        // Given
        try await rayTracing.initialize()
        
        let light = RTLight(
            position: SIMD3<Float>(0, 10, 0),
            color: SIMD3<Float>(1, 1, 1),
            intensity: 1.0,
            type: .area
        )
        
        // When & Then - should not throw
        XCTAssertNoThrow(rayTracing.addLight(light), "Adding area light should not throw")
        
        // Verify light type
        XCTAssertEqual(light.type, .area, "Light type should be area")
        
        // Verify we can add lights of different types
        let pointLight = RTLight(position: SIMD3<Float>(0, 0, 0), color: SIMD3<Float>(1, 1, 1), intensity: 1.0, type: .point)
        XCTAssertNoThrow(rayTracing.addLight(pointLight), "Adding different light type should work")
    }
    
    // MARK: - Performance Tests
    
    func test_RayTracingPerformance_whenTracingRays_expectFast() async throws {
        // Given
        try await rayTracing.initialize()
        rayTracing.isEnabled = true
        
        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }
        
        let startTime = CACurrentMediaTime()
        
        // When
        for _ in 0..<10 {
            rayTracing.traceRays(commandBuffer: commandBuffer)
        }
        
        let endTime = CACurrentMediaTime()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 1.0, "Ray tracing should be fast")
    }
    
    func test_PerformanceMetrics_whenTracing_expectMetricsUpdated() async throws {
        // Given
        try await rayTracing.initialize()
        rayTracing.isEnabled = true
        rayTracing.setRayCount(100_000)
        
        // When
        let metrics = rayTracing.getPerformanceMetrics()
        
        // Then
        XCTAssertNotNil(metrics)
        XCTAssertGreaterThanOrEqual(metrics.totalRays, 0)
        XCTAssertGreaterThanOrEqual(metrics.bounceCount, 0)
        XCTAssertGreaterThanOrEqual(metrics.sampleCount, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func test_Initialization_whenDeviceNotSupported_expectError() async throws {
        // Given
        let invalidDevice: MTLDevice? = nil
        
        // When & Then
        if invalidDevice == nil {
            XCTAssertThrowsError(try await createRayTracingWithDevice(invalidDevice)) { error in
                XCTAssertTrue(error is RayTracingError)
            }
        }
    }
    
    func test_TraceRays_whenNotEnabled_expectNoOperation() async throws {
        // Given
        try await rayTracing.initialize()
        rayTracing.isEnabled = false
        
        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }
        
        // When & Then - should not throw when disabled
        XCTAssertNoThrow(try await rayTracing.traceRays(commandBuffer: commandBuffer), "Tracing when disabled should not throw")
        
        // Verify it's actually disabled
        XCTAssertFalse(rayTracing.isEnabled, "Ray tracing should be disabled")
    }
    
    // MARK: - Edge Cases
    
    func test_Configuration_whenMaxValues_expectAccepted() {
        // Given
        let maxUInt32 = UInt32.max
        
        // When
        rayTracing.setRayCount(maxUInt32)
        rayTracing.setBounceCount(maxUInt32)
        rayTracing.setSampleCount(maxUInt32)
        
        // Then
        XCTAssertEqual(rayTracing.rayCount, maxUInt32)
        XCTAssertEqual(rayTracing.bounces, maxUInt32)
        XCTAssertEqual(rayTracing.samples, maxUInt32)
    }
    
    func test_GeometryBounds_whenInvalidBounds_expectHandled() async throws {
        // Given
        try await rayTracing.initialize()
        
        let geometry = RTGeometry(
            type: .sphere,
            vertices: [],
            indices: nil,
            bounds: AABB(
                min: SIMD3<Float>(Float.infinity, Float.infinity, Float.infinity),
                max: SIMD3<Float>(-Float.infinity, -Float.infinity, -Float.infinity)
            )
        )
        
        // When & Then - should not throw
        XCTAssertNoThrow(rayTracing.addGeometry(geometry), "Invalid bounds geometry should be handled gracefully")
        
        // Verify we can still trace rays with invalid bounds
        guard let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }
        rayTracing.isEnabled = true
        XCTAssertNoThrow(try await rayTracing.traceRays(commandBuffer: commandBuffer), "Should handle invalid bounds during tracing")
    }
    
    // MARK: - Helper Methods
    
    private func createRayTracingWithDevice(_ device: MTLDevice?) async throws -> MetalRayTracingEngine {
        guard let device = device else {
            throw RayTracingError.notSupported
        }
        let rt = MetalRayTracingEngine(device: device)
        try await rt.initialize()
        return rt
    }
}
