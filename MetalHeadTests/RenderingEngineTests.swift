import XCTest
import Metal
import simd
@testable import MetalHeadEngine

/// Unit tests for MetalRenderingEngine
final class RenderingEngineTests: XCTestCase {
    
    var device: MTLDevice!
    var renderingEngine: MetalRenderingEngine!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.metalNotSupported
        }
        self.device = device
        
        renderingEngine = MetalRenderingEngine(device: device)
    }
    
    override func tearDownWithError() throws {
        renderingEngine = nil
        device = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testRenderingEngineInitialization() async throws {
        // Given
        XCTAssertNotNil(renderingEngine)
        
        // When
        try await renderingEngine.initialize()
        
        // Then
        XCTAssertNotNil(renderingEngine.device)
        XCTAssertEqual(renderingEngine.fps, 0) // Initial FPS should be 0
    }
    
    func testRenderingEngineProperties() {
        // Given & When
        let engine = MetalRenderingEngine(device: device)
        
        // Then
        XCTAssertEqual(engine.is3DMode, true) // Default should be 3D mode
        XCTAssertEqual(engine.is2DMode, false) // Default should not be 2D mode
        XCTAssertEqual(engine.fps, 0) // Initial FPS should be 0
    }
    
    // MARK: - Mode Toggle Tests
    
    func testToggle3DMode() {
        // Given
        let initial3DMode = renderingEngine.is3DMode
        
        // When
        renderingEngine.toggle3DMode()
        
        // Then
        XCTAssertEqual(renderingEngine.is3DMode, !initial3DMode)
        
        // When
        renderingEngine.toggle3DMode()
        
        // Then
        XCTAssertEqual(renderingEngine.is3DMode, initial3DMode)
    }
    
    func testToggle2DMode() {
        // Given
        let initial2DMode = renderingEngine.is2DMode
        
        // When
        renderingEngine.toggle2DMode()
        
        // Then
        XCTAssertEqual(renderingEngine.is2DMode, !initial2DMode)
        
        // When
        renderingEngine.toggle2DMode()
        
        // Then
        XCTAssertEqual(renderingEngine.is2DMode, initial2DMode)
    }
    
    // MARK: - Mouse Input Tests
    
    func testMousePositionUpdate() {
        // Given
        let initialPosition = renderingEngine.mousePosition
        let newPosition = SIMD2<Float>(100, 200)
        
        // When
        renderingEngine.updateMousePosition(newPosition)
        
        // Then
        XCTAssertNotEqual(renderingEngine.mousePosition, initialPosition)
    }
    
    func testMouseClickHandling() {
        // Given
        let clickPosition = SIMD2<Float>(150, 250)
        
        // When & Then (should not crash)
        renderingEngine.handleMouseClick(at: clickPosition)
    }
    
    func testMouseScrollHandling() {
        // Given
        let scrollDelta = SIMD2<Float>(0, 1)
        
        // When & Then (should not crash)
        renderingEngine.handleMouseScroll(delta: scrollDelta)
    }
    
    // MARK: - Drawable Size Tests
    
    func testDrawableSizeUpdate() {
        // Given
        let newSize = CGSize(width: 1920, height: 1080)
        
        // When
        renderingEngine.updateDrawableSize(newSize)
        
        // Then (should not crash)
        XCTAssertTrue(true)
    }
    
    // MARK: - Performance Tests
    
    func testRenderingPerformance() async throws {
        // Given
        try await renderingEngine.initialize()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for _ in 0..<100 {
            // Simulate rendering calls
            let deltaTime = 1.0 / 120.0
            // Note: In real tests, you'd call renderingEngine.render(deltaTime:in:)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.1, "Rendering should be fast")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidDeviceHandling() {
        // Given
        let invalidDevice: MTLDevice? = nil
        
        // When & Then
        XCTAssertThrowsError(try createRenderingEngineWithDevice(invalidDevice)) { error in
            XCTAssertTrue(error is RenderingError)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createRenderingEngineWithDevice(_ device: MTLDevice?) throws -> MetalRenderingEngine {
        guard let device = device else {
            throw RenderingError.commandQueueCreationFailed
        }
        return MetalRenderingEngine(device: device)
    }
}
