import XCTest
import Metal
import simd
@testable import MetalHeadEngine

@MainActor
final class DeferredRendererTests: XCTestCase {
    
    var device: MTLDevice!
    var deferredRenderer: DeferredRenderer!
    var commandQueue: MTLCommandQueue!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Metal not available"])
        }
        self.device = device
        self.deferredRenderer = DeferredRenderer(device: device)
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw NSError(domain: "TestError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Command queue creation failed"])
        }
        self.commandQueue = commandQueue
    }
    
    override func tearDownWithError() throws {
        deferredRenderer = nil
        commandQueue = nil
        device = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func test_Initialize_whenValidSize_expectSuccess() throws {
        // When
        try deferredRenderer.initialize(width: 800, height: 600)
        
        // Then - verify G-Buffer textures are created
        XCTAssertNotNil(deferredRenderer.getGBufferAlbedo(), "G-Buffer albedo texture should be created")
        XCTAssertNotNil(deferredRenderer.getGBufferNormal(), "G-Buffer normal texture should be created")
        XCTAssertNotNil(deferredRenderer.getGBufferDepth(), "G-Buffer depth texture should be created")
        XCTAssertNotNil(deferredRenderer.getLightingTexture(), "Lighting texture should be created")
    }
    
    func test_Initialize_whenDifferentSizes_expectCorrectTextures() throws {
        // When
        try deferredRenderer.initialize(width: 1920, height: 1080)
        
        // Then
        let albedo = deferredRenderer.getGBufferAlbedo()
        XCTAssertNotNil(albedo, "Albedo texture should exist")
        XCTAssertEqual(albedo?.width, 1920, "Albedo width should match")
        XCTAssertEqual(albedo?.height, 1080, "Albedo height should match")
    }
    
    func test_UpdateSize_whenInitialized_expectTexturesResized() throws {
        // Given
        try deferredRenderer.initialize(width: 800, height: 600)
        let originalAlbedo = deferredRenderer.getGBufferAlbedo()
        
        // When
        try deferredRenderer.updateSize(width: 1024, height: 768)
        
        // Then
        let newAlbedo = deferredRenderer.getGBufferAlbedo()
        XCTAssertNotNil(newAlbedo, "New albedo texture should exist")
        XCTAssertEqual(newAlbedo?.width, 1024, "Width should be updated")
        XCTAssertEqual(newAlbedo?.height, 768, "Height should be updated")
        XCTAssertNotEqual(originalAlbedo, newAlbedo, "Should be a new texture")
    }
    
    // MARK: - G-Buffer Rendering Tests
    
    func test_RenderGBuffer_whenInitialized_expectNoError() throws {
        // Given
        try deferredRenderer.initialize(width: 800, height: 600)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }
        
        let viewMatrix = matrix_identity_float4x4
        let geometries: [DeferredGeometry] = []
        
        // When & Then - should not throw
        XCTAssertNoThrow(try deferredRenderer.renderGBuffer(
            commandBuffer: commandBuffer,
            cameraViewMatrix: viewMatrix,
            geometries: geometries
        ), "G-Buffer rendering should not throw with empty geometries")
    }
    
    func test_RenderGBuffer_whenWithGeometry_expectEncoded() throws {
        // Given
        try deferredRenderer.initialize(width: 800, height: 600)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }
        
        // Create test geometry
        let vertices: [Vertex] = [
            Vertex(position: SIMD3<Float>(0, 0, 0), color: SIMD4<Float>(1, 0, 0, 1)),
            Vertex(position: SIMD3<Float>(1, 0, 0), color: SIMD4<Float>(0, 1, 0, 1)),
            Vertex(position: SIMD3<Float>(0, 1, 0), color: SIMD4<Float>(0, 0, 1, 1))
        ]
        
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: []) else {
            XCTFail("Failed to create vertex buffer")
            return
        }
        
        let material = DeferredMaterial(albedo: SIMD3<Float>(1, 1, 1), roughness: 0.5, metallic: 0.0)
        let geometry = DeferredGeometry(
            vertexBuffer: vertexBuffer,
            indexBuffer: nil,
            vertexCount: 3,
            indexCount: 0,
            material: material
        )
        
        let viewMatrix = matrix_identity_float4x4
        
        // When & Then
        XCTAssertNoThrow(try deferredRenderer.renderGBuffer(
            commandBuffer: commandBuffer,
            cameraViewMatrix: viewMatrix,
            geometries: [geometry]
        ), "G-Buffer rendering should work with geometry")
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    // MARK: - Lighting Pass Tests
    
    func test_RenderLighting_whenInitialized_expectNoError() throws {
        // Given
        try deferredRenderer.initialize(width: 800, height: 600)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }
        
        let lights: [DeferredLight] = []
        
        // When & Then
        XCTAssertNoThrow(try deferredRenderer.renderLighting(
            commandBuffer: commandBuffer,
            lights: lights
        ), "Lighting pass should work with no lights")
    }
    
    func test_RenderLighting_whenWithLights_expectEncoded() throws {
        // Given
        try deferredRenderer.initialize(width: 800, height: 600)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }
        
        let lights: [DeferredLight] = [
            DeferredLight(
                position: SIMD3<Float>(0, 5, 0),
                color: SIMD3<Float>(1, 1, 1),
                intensity: 1.0,
                radius: 10.0
            ),
            DeferredLight(
                position: SIMD3<Float>(-5, 0, 0),
                color: SIMD3<Float>(1, 0, 0),
                intensity: 0.5,
                radius: 5.0
            )
        ]
        
        // When & Then
        XCTAssertNoThrow(try deferredRenderer.renderLighting(
            commandBuffer: commandBuffer,
            lights: lights
        ), "Lighting pass should work with multiple lights")
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    func test_RenderLighting_whenMultipleLights_expectAllProcessed() throws {
        // Given
        try deferredRenderer.initialize(width: 800, height: 600)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }
        
        // Create many lights to test array handling
        let lights = (0..<10).map { index in
            DeferredLight(
                position: SIMD3<Float>(Float(index), 0, 0),
                color: SIMD3<Float>(1, 1, 1),
                intensity: 1.0,
                radius: 10.0
            )
        }
        
        // When & Then
        XCTAssertNoThrow(try deferredRenderer.renderLighting(
            commandBuffer: commandBuffer,
            lights: lights
        ), "Lighting pass should handle multiple lights")
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    // MARK: - Texture Access Tests
    
    func test_GetGBufferTextures_whenInitialized_expectAllAvailable() throws {
        // Given
        try deferredRenderer.initialize(width: 800, height: 600)
        
        // When
        let albedo = deferredRenderer.getGBufferAlbedo()
        let normal = deferredRenderer.getGBufferNormal()
        let depth = deferredRenderer.getGBufferDepth()
        let lighting = deferredRenderer.getLightingTexture()
        
        // Then
        XCTAssertNotNil(albedo, "Albedo texture should be accessible")
        XCTAssertNotNil(normal, "Normal texture should be accessible")
        XCTAssertNotNil(depth, "Depth texture should be accessible")
        XCTAssertNotNil(lighting, "Lighting texture should be accessible")
        
        // Verify texture properties
        XCTAssertEqual(albedo?.width, 800, "Albedo width should match")
        XCTAssertEqual(albedo?.height, 600, "Albedo height should match")
        XCTAssertEqual(normal?.width, 800, "Normal width should match")
        XCTAssertEqual(normal?.height, 600, "Normal height should match")
    }
    
    // MARK: - Full Pipeline Tests
    
    func test_FullPipeline_whenComplete_expectSuccess() throws {
        // Given
        try deferredRenderer.initialize(width: 800, height: 600)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }
        
        // Create test geometry
        let vertices: [Vertex] = [
            Vertex(position: SIMD3<Float>(-1, -1, 0), color: SIMD4<Float>(1, 0, 0, 1)),
            Vertex(position: SIMD3<Float>(1, -1, 0), color: SIMD4<Float>(0, 1, 0, 1)),
            Vertex(position: SIMD3<Float>(0, 1, 0), color: SIMD4<Float>(0, 0, 1, 1))
        ]
        
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: []) else {
            XCTFail("Failed to create vertex buffer")
            return
        }
        
        let material = DeferredMaterial(albedo: SIMD3<Float>(0.8, 0.8, 0.8), roughness: 0.5, metallic: 0.0)
        let geometry = DeferredGeometry(
            vertexBuffer: vertexBuffer,
            indexBuffer: nil,
            vertexCount: 3,
            indexCount: 0,
            material: material
        )
        
        let lights: [DeferredLight] = [
            DeferredLight(
                position: SIMD3<Float>(0, 5, 5),
                color: SIMD3<Float>(1, 1, 1),
                intensity: 1.0,
                radius: 20.0
            )
        ]
        
        // When - render full pipeline
        XCTAssertNoThrow(try deferredRenderer.renderGBuffer(
            commandBuffer: commandBuffer,
            cameraViewMatrix: matrix_identity_float4x4,
            geometries: [geometry]
        ), "G-Buffer pass should succeed")
        
        XCTAssertNoThrow(try deferredRenderer.renderLighting(
            commandBuffer: commandBuffer,
            lights: lights
        ), "Lighting pass should succeed")
        
        // Then
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Verify final texture exists
        let lightingTexture = deferredRenderer.getLightingTexture()
        XCTAssertNotNil(lightingTexture, "Lighting texture should exist after rendering")
    }
}


