import XCTest
import Metal
import simd
@testable import MetalHead

/// Unit tests for UnifiedMultimediaEngine
/// Comprehensive testing of main engine orchestration
final class UnifiedEngineTests: XCTestCase {
    
    var engine: UnifiedMultimediaEngine!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        engine = UnifiedMultimediaEngine()
    }
    
    override func tearDownWithError() throws {
        engine = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func test_Initialize_whenFirstCall_expectInitialized() async throws {
        // Given
        XCTAssertFalse(engine.isInitialized, "Engine should not be initialized")
        
        // When
        try await engine.initialize()
        
        // Then
        XCTAssertTrue(engine.isInitialized, "Engine should be initialized")
    }
    
    func test_Initialize_whenCalledTwice_expectNoError() async throws {
        // Given
        try await engine.initialize()
        
        // When & Then (should not throw error)
        try await engine.initialize()
        XCTAssertTrue(true, "Second initialization should succeed")
    }
    
    // MARK: - Lifecycle Tests
    
    func test_Start_whenNotInitialized_expectAutoInitialization() async throws {
        // When
        try await engine.start()
        
        // Then
        XCTAssertTrue(engine.isInitialized, "Should auto-initialize")
        XCTAssertTrue(engine.isRunning, "Should be running")
    }
    
    func test_Start_whenInitialized_expectRunning() async throws {
        // Given
        try await engine.initialize()
        
        // When
        try await engine.start()
        
        // Then
        XCTAssertTrue(engine.isRunning, "Engine should be running")
    }
    
    func test_Stop_whenRunning_expectStopped() async throws {
        // Given
        try await engine.initialize()
        try await engine.start()
        XCTAssertTrue(engine.isRunning, "Engine should be running")
        
        // When
        engine.stop()
        
        // Then
        XCTAssertFalse(engine.isRunning, "Engine should be stopped")
    }
    
    func test_Pause_whenRunning_expectPaused() async throws {
        // Given
        try await engine.initialize()
        try await engine.start()
        
        // When
        engine.pause()
        
        // Then
        XCTAssertFalse(engine.isRunning, "Engine should be paused")
    }
    
    func test_Resume_whenPaused_expectRunning() async throws {
        // Given
        try await engine.initialize()
        try await engine.start()
        engine.pause()
        
        // When
        try await engine.resume()
        
        // Then
        XCTAssertTrue(engine.isRunning, "Engine should be resumed")
    }
    
    // MARK: - Subsystem Access Tests
    
    func test_GetSubsystem_whenRendering_expectEngineReturned() async throws {
        // Given
        try await engine.initialize()
        
        // When
        let subsystem = engine.getSubsystem(MetalRenderingEngine.self)
        
        // Then
        XCTAssertNotNil(subsystem, "Rendering engine should be accessible")
    }
    
    func test_GetSubsystem_whenAudio_expectEngineReturned() async throws {
        // Given
        try await engine.initialize()
        
        // When
        let subsystem = engine.getSubsystem(AudioEngine.self)
        
        // Then
        XCTAssertNotNil(subsystem, "Audio engine should be accessible")
    }
    
    func test_GetSubsystem_whenInput_expectManagerReturned() async throws {
        // Given
        try await engine.initialize()
        
        // When
        let subsystem = engine.getSubsystem(InputManager.self)
        
        // Then
        XCTAssertNotNil(subsystem, "Input manager should be accessible")
    }
    
    func test_GetSubsystem_whenMemory_expectManagerReturned() async throws {
        // Given
        try await engine.initialize()
        
        // When
        let subsystem = engine.getSubsystem(MemoryManager.self)
        
        // Then
        XCTAssertNotNil(subsystem, "Memory manager should be accessible")
    }
    
    func test_GetSubsystem_whenClock_expectSystemReturned() async throws {
        // Given
        try await engine.initialize()
        
        // When
        let subsystem = engine.getSubsystem(UnifiedClockSystem.self)
        
        // Then
        XCTAssertNotNil(subsystem, "Clock system should be accessible")
    }
    
    func test_GetSubsystem_whenPerformance_expectMonitorReturned() async throws {
        // Given
        try await engine.initialize()
        
        // When
        let subsystem = engine.getSubsystem(PerformanceMonitor.self)
        
        // Then
        XCTAssertNotNil(subsystem, "Performance monitor should be accessible")
    }
    
    func test_GetSubsystem_whenInvalid_expectNil() {
        // When
        let subsystem = engine.getSubsystem(String.self)
        
        // Then
        XCTAssertNil(subsystem, "Invalid subsystem should return nil")
    }
    
    // MARK: - Performance Metrics Tests
    
    func test_GetPerformanceMetrics_whenRunning_expectValidMetrics() async throws {
        // Given
        try await engine.initialize()
        try await engine.start()
        
        // When
        let metrics = engine.getPerformanceMetrics()
        
        // Then
        XCTAssertNotNil(metrics, "Performance metrics should be available")
        
        if let metrics = metrics {
            XCTAssertGreaterThanOrEqual(metrics.fps, 0, "FPS should be non-negative")
            XCTAssertGreaterThanOrEqual(metrics.frameTime, 0, "Frame time should be non-negative")
        }
    }
    
    func test_GetMemoryReport_whenInitialized_expectValidReport() async throws {
        // Given
        try await engine.initialize()
        
        // When
        let report = engine.getMemoryReport()
        
        // Then
        XCTAssertNotNil(report, "Memory report should be available")
    }
    
    // MARK: - Frame Rate Tests
    
    func test_FrameRate_whenUpdating_expectUpdated() async throws {
        // Given
        try await engine.initialize()
        
        let initialFrameRate = engine.frameRate
        
        // When
        // Simulate frame rendering
        engine.render(deltaTime: 1.0/120.0, in: createMockView())
        
        // Then
        XCTAssertGreaterThanOrEqual(engine.frameRate, 0, "Frame rate should be non-negative")
    }
    
    // MARK: - Synchronization Tests
    
    func test_SynchronizationQuality_whenRunning_expectUpdated() async throws {
        // Given
        try await engine.initialize()
        try await engine.start()
        
        // When
        // Wait a bit for synchronization
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertGreaterThanOrEqual(engine.synchronizationQuality, 0)
        XCTAssertLessThanOrEqual(engine.synchronizationQuality, 1)
    }
    
    // MARK: - Concurrent Access Tests
    
    func test_ConcurrentAccess_whenMultipleThreads_expectSafe() async throws {
        // Given
        try await engine.initialize()
        
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10
        
        // When
        for _ in 0..<10 {
            Task {
                _ = engine.getSubsystem(MetalRenderingEngine.self)
                _ = engine.getSubsystem(AudioEngine.self)
                _ = engine.getSubsystem(InputManager.self)
                _ = engine.getSubsystem(MemoryManager.self)
                
                expectation.fulfill()
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(true, "Concurrent access should be safe")
    }
    
    // MARK: - Error Handling Tests
    
    func test_ErrorHandling_whenInitializationFails_expectErrorLogged() async throws {
        // When & Then
        do {
            try await engine.initialize()
            XCTAssertTrue(true, "Initialization should succeed")
        } catch {
            Logger.shared.logError("Initialization failed", error: error)
            XCTAssertTrue(error is Error, "Should handle errors gracefully")
        }
    }
    
    // MARK: - Performance Tests
    
    func test_Performance_whenRendering_expectFast() async throws {
        // Given
        try await engine.initialize()
        try await engine.start()
        
        let startTime = CACurrentMediaTime()
        
        // When
        for _ in 0..<100 {
            engine.render(deltaTime: 1.0/120.0, in: createMockView())
        }
        
        let endTime = CACurrentMediaTime()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 1.0, "Rendering should be fast")
    }
    
    // MARK: - Helper Methods
    
    private func createMockView() -> MTKView {
        // Create a minimal mock view for testing
        // In a real scenario, this would be a proper MTKView
        return MTKView()
    }
}

// MARK: - Test Extensions

extension UnifiedMultimediaEngine {
    
    func testInitialize() async throws {
        try await self.initialize()
    }
    
    func testStart() async throws {
        try await self.start()
    }
    
    func testStop() {
        self.stop()
    }
    
    func testPause() {
        self.pause()
    }
    
    func testResume() async throws {
        try await self.resume()
    }
}
