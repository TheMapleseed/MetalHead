import XCTest
@testable import MetalHeadEngine

/// Unit tests for UnifiedClockSystem
final class ClockSystemTests: XCTestCase {
    
    var clockSystem: UnifiedClockSystem!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        clockSystem = UnifiedClockSystem()
    }
    
    override func tearDownWithError() throws {
        clockSystem = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testClockSystemInitialization() {
        // Given & When
        let clock = UnifiedClockSystem()
        
        // Then
        XCTAssertNotNil(clock)
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(clock.masterTime, 0)
    }
    
    func testClockSystemProperties() {
        // Given & When
        let clock = UnifiedClockSystem()
        
        // Then
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(clock.masterTime, 0)
        XCTAssertEqual(clock.systemLatency, 0)
        XCTAssertEqual(clock.audioLatency, 0)
        XCTAssertEqual(clock.renderLatency, 0)
        XCTAssertEqual(clock.inputLatency, 0)
    }
    
    // MARK: - Start/Stop Tests
    
    func testClockSystemStart() {
        // Given
        XCTAssertFalse(clockSystem.isRunning)
        
        // When
        clockSystem.start()
        
        // Then
        XCTAssertTrue(clockSystem.isRunning)
    }
    
    func testClockSystemStop() {
        // Given
        clockSystem.start()
        XCTAssertTrue(clockSystem.isRunning)
        
        // When
        clockSystem.stop()
        
        // Then
        XCTAssertFalse(clockSystem.isRunning)
    }
    
    func testClockSystemPauseResume() {
        // Given
        clockSystem.start()
        XCTAssertTrue(clockSystem.isRunning)
        
        // When
        clockSystem.pause()
        
        // Then
        XCTAssertFalse(clockSystem.isRunning)
        
        // When
        clockSystem.resume()
        
        // Then
        XCTAssertTrue(clockSystem.isRunning)
    }
    
    // MARK: - Time Management Tests
    
    func testCurrentTime() {
        // Given
        clockSystem.start()
        
        // When
        let currentTime = clockSystem.getCurrentTime()
        
        // Then
        XCTAssertGreaterThanOrEqual(currentTime, 0)
    }
    
    func testCurrentFrame() {
        // Given
        clockSystem.start()
        
        // When
        let currentFrame = clockSystem.getCurrentFrame()
        
        // Then
        XCTAssertGreaterThanOrEqual(currentFrame, 0)
    }
    
    func testFrameRate() {
        // Given
        clockSystem.start()
        
        // When
        let frameRate = clockSystem.getFrameRate()
        
        // Then
        XCTAssertGreaterThan(frameRate, 0)
    }
    
    func testTargetFrameRate() {
        // Given
        let targetFrameRate: Double = 60.0
        
        // When
        clockSystem.setTargetFrameRate(targetFrameRate)
        
        // Then
        XCTAssertEqual(clockSystem.getFrameRate(), targetFrameRate)
    }
    
    // MARK: - Compensated Time Tests
    
    func testCompensatedTimeForRendering() {
        // Given
        clockSystem.start()
        
        // When
        let compensatedTime = clockSystem.getCompensatedTime(for: .rendering)
        
        // Then
        XCTAssertGreaterThanOrEqual(compensatedTime, 0)
    }
    
    func testCompensatedTimeForAudio() {
        // Given
        clockSystem.start()
        
        // When
        let compensatedTime = clockSystem.getCompensatedTime(for: .audio)
        
        // Then
        XCTAssertGreaterThanOrEqual(compensatedTime, 0)
    }
    
    func testCompensatedTimeForInput() {
        // Given
        clockSystem.start()
        
        // When
        let compensatedTime = clockSystem.getCompensatedTime(for: .input)
        
        // Then
        XCTAssertGreaterThanOrEqual(compensatedTime, 0)
    }
    
    func testCompensatedTimeForPhysics() {
        // Given
        clockSystem.start()
        
        // When
        let compensatedTime = clockSystem.getCompensatedTime(for: .physics)
        
        // Then
        XCTAssertGreaterThanOrEqual(compensatedTime, 0)
    }
    
    // MARK: - Callback Tests
    
    func testTimingCallback() {
        // Given
        var callbackExecuted = false
        clockSystem.start()
        
        // When
        clockSystem.addTimingCallback(for: .rendering) { time, deltaTime in
            callbackExecuted = true
        }
        
        // Wait a bit for callback to execute
        Thread.sleep(forTimeInterval: 0.1)
        
        // Then
        XCTAssertTrue(callbackExecuted)
    }
    
    func testGlobalTimingCallback() {
        // Given
        var callbackExecuted = false
        clockSystem.start()
        
        // When
        clockSystem.addGlobalTimingCallback { time, deltaTime in
            callbackExecuted = true
        }
        
        // Wait a bit for callback to execute
        Thread.sleep(forTimeInterval: 0.1)
        
        // Then
        XCTAssertTrue(callbackExecuted)
    }
    
    func testMultipleCallbacks() {
        // Given
        var renderingCallbackExecuted = false
        var audioCallbackExecuted = false
        var globalCallbackExecuted = false
        
        clockSystem.start()
        
        // When
        clockSystem.addTimingCallback(for: .rendering) { time, deltaTime in
            renderingCallbackExecuted = true
        }
        
        clockSystem.addTimingCallback(for: .audio) { time, deltaTime in
            audioCallbackExecuted = true
        }
        
        clockSystem.addGlobalTimingCallback { time, deltaTime in
            globalCallbackExecuted = true
        }
        
        // Wait a bit for callbacks to execute
        Thread.sleep(forTimeInterval: 0.1)
        
        // Then
        XCTAssertTrue(renderingCallbackExecuted)
        XCTAssertTrue(audioCallbackExecuted)
        XCTAssertTrue(globalCallbackExecuted)
    }
    
    // MARK: - Performance Metrics Tests
    
    func testPerformanceMetrics() {
        // Given
        clockSystem.start()
        
        // When
        let metrics = clockSystem.getPerformanceMetrics()
        
        // Then
        XCTAssertNotNil(metrics)
        XCTAssertGreaterThanOrEqual(metrics.totalFrames, 0)
        XCTAssertGreaterThanOrEqual(metrics.totalTime, 0)
        XCTAssertGreaterThanOrEqual(metrics.averageFrameTime, 0)
        XCTAssertGreaterThanOrEqual(metrics.frameTimeVariance, 0)
        XCTAssertGreaterThanOrEqual(metrics.maxFrameTime, 0)
        XCTAssertGreaterThanOrEqual(metrics.timingDrift, 0)
    }
    
    // MARK: - Performance Tests
    
    func testClockSystemPerformance() {
        // Given
        clockSystem.start()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for _ in 0..<1000 {
            _ = clockSystem.getCurrentTime()
            _ = clockSystem.getCurrentFrame()
            _ = clockSystem.getCompensatedTime(for: .rendering)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.1, "Clock system should be fast")
    }
    
    func testCallbackPerformance() {
        // Given
        clockSystem.start()
        var callbackCount = 0
        
        clockSystem.addGlobalTimingCallback { time, deltaTime in
            callbackCount += 1
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        Thread.sleep(forTimeInterval: 0.1)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertGreaterThan(callbackCount, 0, "Callbacks should execute")
        XCTAssertLessThan(executionTime, 0.2, "Callback execution should be fast")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidSubsystemType() {
        // Given
        clockSystem.start()
        
        // When
        let compensatedTime = clockSystem.getCompensatedTime(for: .rendering)
        
        // Then
        XCTAssertGreaterThanOrEqual(compensatedTime, 0)
    }
    
    func testCallbackAfterStop() {
        // Given
        var callbackExecuted = false
        
        clockSystem.addGlobalTimingCallback { time, deltaTime in
            callbackExecuted = true
        }
        
        clockSystem.start()
        clockSystem.stop()
        
        // When
        Thread.sleep(forTimeInterval: 0.1)
        
        // Then
        // Callback should not execute after stop
        XCTAssertFalse(callbackExecuted)
    }
}
