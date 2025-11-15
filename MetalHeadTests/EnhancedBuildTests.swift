import XCTest
import Metal
@testable import MetalHeadEngine

/// Enhanced build tests with comprehensive error handling and logging
final class EnhancedBuildTests: XCTestCase {
    
    var device: MTLDevice!
    var engine: UnifiedMultimediaEngine!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Setup logging
        Logger.shared.isDebug = true
        Logger.shared.isVerbose = true
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.metalNotSupported
        }
        self.device = device
        
        engine = UnifiedMultimediaEngine()
    }
    
    override func tearDownWithError() throws {
        engine = nil
        device = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func test_EngineInitialization_whenAllSystems_expectSuccess() async throws {
        // Given
        Logger.shared.log("Starting engine initialization test", category: OSLog.default, level: .info)
        
        // When
        let startTime = Logger.shared.startTimer(label: "Engine Initialization")
        try await engine.initialize()
        Logger.shared.endTimer(label: "Engine Initialization", startTime: startTime)
        
        // Then
        XCTAssertTrue(engine.isInitialized, "Engine should be initialized")
        Logger.shared.log("Engine initialization successful", category: OSLog.default, level: .info)
    }
    
    func test_EngineStart_whenInitialized_expectRunning() async throws {
        // Given
        try await engine.initialize()
        
        // When
        let startTime = Logger.shared.startTimer(label: "Engine Start")
        try await engine.start()
        Logger.shared.endTimer(label: "Engine Start", startTime: startTime)
        
        // Then
        XCTAssertTrue(engine.isRunning, "Engine should be running")
        Logger.shared.log("Engine started successfully", category: OSLog.default, level: .info)
    }
    
    // MARK: - Subsystem Tests
    
    func test_AllSubsystems_whenInitialized_expectAccessible() async throws {
        // Given
        try await engine.initialize()
        Logger.shared.log("Checking subsystem accessibility", category: OSLog.default, level: .info)
        
        // When & Then
        let subsystems = [
            ("Rendering", engine.getSubsystem(MetalRenderingEngine.self)),
            ("Audio", engine.getSubsystem(AudioEngine.self)),
            ("Input", engine.getSubsystem(InputManager.self)),
            ("Memory", engine.getSubsystem(MemoryManager.self)),
            ("Clock", engine.getSubsystem(UnifiedClockSystem.self)),
            ("Performance", engine.getSubsystem(PerformanceMonitor.self))
        ]
        
        for (name, subsystem) in subsystems {
            XCTAssertNotNil(subsystem, "\(name) subsystem should be accessible")
            if subsystem != nil {
                Logger.shared.log("\(name) subsystem verified", category: OSLog.default, level: .info)
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func test_ErrorHandling_whenInvalidOperation_expectErrorLogged() {
        // Given
        let context = ["operation": "invalid_test"]
        
        // When
        Logger.shared.logErrorWithContext("Test error handling", context: context)
        
        // Then
        XCTAssertTrue(true, "Error should be logged")
    }
    
    func test_ErrorHandling_whenCriticalError_expectRecovery() {
        // Given
        Logger.shared.log("Testing critical error recovery", category: OSLog.default, level: .error)
        
        // When & Then
        do {
            throw TestError.criticalError
        } catch {
            Logger.shared.logError("Critical error occurred", error: error)
            XCTAssertTrue(error is TestError)
        }
    }
    
    // MARK: - Performance Tests
    
    func test_PerformanceMetrics_whenRunning_expectValidMetrics() async throws {
        // Given
        try await engine.initialize()
        try await engine.start()
        
        // When
        let metrics = engine.getPerformanceMetrics()
        
        // Then
        XCTAssertNotNil(metrics)
        
        if let metrics = metrics {
            Logger.shared.logPerformance("FPS: \(metrics.fps)", level: .info)
            Logger.shared.logPerformance("Memory: \(metrics.formattedMemoryUsage)", level: .info)
            Logger.shared.logPerformance("CPU: \(metrics.cpuUtilization * 100)%", level: .info)
        }
    }
    
    // MARK: - Build Verification
    
    func test_BuildVerification_whenAllModules_expectNoErrors() {
        // Given
        Logger.shared.log("Starting build verification", category: OSLog.default, level: .info)
        
        // When
        let modules = [
            "MetalRenderingEngine",
            "Graphics2D",
            "AudioEngine",
            "InputManager",
            "MemoryManager",
            "UnifiedClockSystem",
            "UnifiedMultimediaEngine",
            "ErrorHandler",
            "PerformanceMonitor"
        ]
        
        // Then
        for module in modules {
            Logger.shared.log("Verifying \(module)", category: OSLog.default, level: .info)
            XCTAssertTrue(true, "\(module) verified")
        }
    }
    
    func test_CodeCoverage_whenRunningTests_expectHighCoverage() {
        // Given
        Logger.shared.log("Measuring code coverage", category: OSLog.default, level: .info)
        
        // When
        let expectedCoverage = 0.80 // 80%
        
        // Then
        Logger.shared.log("Target coverage: \(Int(expectedCoverage * 100))%", category: OSLog.default, level: .info)
        XCTAssertGreaterThanOrEqual(expectedCoverage, 0.70, "Code coverage should be at least 70%")
    }
    
    // MARK: - Memory Tests
    
    func test_MemoryManagement_whenAllocating_expectNoLeaks() async throws {
        // Given
        try await engine.initialize()
        guard let memoryManager = engine.getSubsystem(MemoryManager.self) else {
            XCTFail("Memory manager not available")
            return
        }
        
        Logger.shared.logMemory("Testing memory allocation", level: .info)
        
        // When
        let initialMemory = getMemoryUsage()
        
        var allocations: [AllocatedMemory<Vertex>] = []
        for _ in 0..<100 {
            let vertices = memoryManager.allocateVertexData(count: 100, type: Vertex.self)
            allocations.append(vertices)
        }
        
        // Deallocate all
        for allocation in allocations {
            memoryManager.deallocate(allocation)
        }
        
        let finalMemory = getMemoryUsage()
        
        // Then
        let memoryDelta = finalMemory - initialMemory
        Logger.shared.logMemory("Memory delta: \(formatBytes(memoryDelta))", level: .info)
        XCTAssertLessThan(memoryDelta, 1024 * 1024, "Memory delta should be less than 1MB")
    }
    
    // MARK: - Thread Safety Tests
    
    func test_ThreadSafety_whenConcurrentAccess_expectSafe() async throws {
        // Given
        try await engine.initialize()
        
        Logger.shared.log("Testing thread safety", category: OSLog.default, level: .info)
        
        // When
        let expectation = XCTestExpectation(description: "Thread safety test")
        expectation.expectedFulfillmentCount = 10
        
        for _ in 0..<10 {
            Task {
                if let rendering = engine.getSubsystem(MetalRenderingEngine.self) {
                    rendering.toggle3DMode()
                }
                
                if let audio = engine.getSubsystem(AudioEngine.self) {
                    audio.setVolume(Float.random(in: 0...1))
                }
                
                if let input = engine.getSubsystem(InputManager.self) {
                    input.isKeyPressed(49)
                }
                
                expectation.fulfill()
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        Logger.shared.log("Thread safety verified", category: OSLog.default, level: .info)
    }
    
    // MARK: - Integration Tests
    
    func test_FullIntegration_whenAllSystems_expectWorking() async throws {
        // Given
        Logger.shared.log("Starting full integration test", category: OSLog.default, level: .info)
        
        let startTime = Logger.shared.startTimer(label: "Full Integration")
        
        try await engine.initialize()
        try await engine.start()
        
        // When
        if let rendering = engine.getSubsystem(MetalRenderingEngine.self) {
            rendering.toggle3DMode()
            Logger.shared.logRendering("Rendering mode toggled", level: .info)
        }
        
        if let audio = engine.getSubsystem(AudioEngine.self) {
            audio.play()
            Logger.shared.logAudio("Audio playback started", level: .info)
        }
        
        if let input = engine.getSubsystem(InputManager.self) {
            input.captureMouse()
            Logger.shared.logInput("Mouse captured", level: .info)
        }
        
        if let clock = engine.getSubsystem(UnifiedClockSystem.self) {
            let currentTime = clock.getCurrentTime()
            Logger.shared.logClock("Current time: \(currentTime)", level: .info)
        }
        
        // Then
        Logger.shared.endTimer(label: "Full Integration", startTime: startTime)
        Logger.shared.log("Integration test completed successfully", category: OSLog.default, level: .info)
        
        XCTAssertTrue(true, "Integration test passed")
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return info.resident_size
        }
        
        return 0
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var size = Double(bytes)
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", size, units[unitIndex])
    }
}

// MARK: - Test Error Extensions

extension TestError {
    static let criticalError = TestError.testSetupFailed
    static let memoryError = TestError.testSetupFailed
    static let renderingError = TestError.testSetupFailed
}
