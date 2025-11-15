import XCTest
import os.log
@testable import MetalHeadEngine

/// Unit tests for Logger system
/// Comprehensive testing of logging functionality
final class LoggerTests: XCTestCase {
    
    var logger: Logger!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        logger = Logger.shared
        logger.isVerbose = true
        logger.isDebug = true
        logger.isProduction = false
        logger.enableLogCapture = true
        logger.clearCapturedLogs()
    }
    
    override func tearDownWithError() throws {
        logger.clearCapturedLogs()
        logger.enableLogCapture = false
        logger = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Rendering Logs
    
    func test_LogRendering_whenCalled_expectLogged() {
        // When
        logger.logRendering("Frame rendered", level: .info)
        logger.logRendering("Rendering pipeline created", level: .debug)
        logger.logRendering("Warning: Low frame rate", level: .warning)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 3, "Should capture 3 rendering logs")
        XCTAssertEqual(logs[0].message, "Frame rendered", "First log message should match")
        XCTAssertEqual(logs[0].category, "Rendering", "First log category should be Rendering")
        XCTAssertEqual(logs[0].level, .info, "First log level should be info")
        XCTAssertEqual(logs[1].message, "Rendering pipeline created", "Second log message should match")
        XCTAssertEqual(logs[1].level, .debug, "Second log level should be debug")
        XCTAssertEqual(logs[2].level, .warning, "Third log level should be warning")
    }
    
    // MARK: - Audio Logs
    
    func test_LogAudio_whenCalled_expectLogged() {
        // When
        logger.logAudio("Audio playback started", level: .info)
        logger.logAudio("Buffer size: 1024", level: .debug)
        logger.logAudio("Warning: Audio interruption", level: .warning)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 3, "Should capture 3 audio logs")
        XCTAssertEqual(logs[0].category, "Audio", "First log category should be Audio")
        XCTAssertEqual(logs[0].message, "Audio playback started", "First log message should match")
        XCTAssertEqual(logs[1].message, "Buffer size: 1024", "Second log message should match")
        XCTAssertEqual(logs[2].message, "Warning: Audio interruption", "Third log message should match")
    }
    
    // MARK: - Input Logs
    
    func test_LogInput_whenCalled_expectLogged() {
        // When
        logger.logInput("Key pressed: Space", level: .info)
        logger.logInput("Mouse position: (100, 200)", level: .debug)
        logger.logInput("Mouse captured", level: .info)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 3, "Should capture 3 input logs")
        XCTAssertEqual(logs[0].category, "Input", "First log category should be Input")
        XCTAssertTrue(logs.contains { $0.message == "Key pressed: Space" }, "Should contain key press log")
        XCTAssertTrue(logs.contains { $0.message == "Mouse position: (100, 200)" }, "Should contain mouse position log")
    }
    
    // MARK: - Memory Logs
    
    func test_LogMemory_whenCalled_expectLogged() {
        // When
        logger.logMemory("Allocated 100MB", level: .info)
        logger.logMemory("Memory pool created", level: .debug)
        logger.logMemory("Warning: High memory usage", level: .warning)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 3, "Should capture 3 memory logs")
        XCTAssertEqual(logs[0].category, "Memory", "First log category should be Memory")
        XCTAssertTrue(logs.contains { $0.message == "Allocated 100MB" }, "Should contain allocation log")
    }
    
    // MARK: - Clock Logs
    
    func test_LogClock_whenCalled_expectLogged() {
        // When
        logger.logClock("Frame time: 16.67ms", level: .info)
        logger.logClock("Time sync successful", level: .debug)
        logger.logClock("Warning: Timing drift detected", level: .warning)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 3, "Should capture 3 clock logs")
        XCTAssertEqual(logs[0].category, "Clock", "First log category should be Clock")
        XCTAssertTrue(logs.contains { $0.message.contains("Frame time") }, "Should contain frame time log")
    }
    
    // MARK: - Performance Logs
    
    func test_LogPerformance_whenCalled_expectLogged() {
        // When
        logger.logPerformance("FPS: 120", level: .info)
        logger.logPerformance("CPU usage: 45%", level: .info)
        logger.logPerformance("GPU usage: 80%", level: .info)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 3, "Should capture 3 performance logs")
        XCTAssertEqual(logs[0].category, "Performance", "First log category should be Performance")
        XCTAssertTrue(logs.contains { $0.message == "FPS: 120" }, "Should contain FPS log")
    }
    
    // MARK: - Error Logs
    
    func test_LogError_whenCalled_expectLogged() {
        // Given
        let testError = NSError(domain: "Test", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // When
        logger.logError("Operation failed", error: testError)
        logger.logError("System error", error: nil)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 2, "Should capture 2 error logs")
        XCTAssertEqual(logs[0].category, "Error", "First log category should be Error")
        XCTAssertEqual(logs[0].level, .error, "First log level should be error")
        XCTAssertTrue(logs[0].message.contains("Operation failed"), "Should contain error message")
        XCTAssertTrue(logs[0].message.contains("Test error"), "Should contain error description")
        XCTAssertEqual(logs[1].message, "System error", "Second log message should match")
    }
    
    func test_LogErrorWithContext_whenCalled_expectLogged() {
        // Given
        let context = [
            "frame": 1234,
            "time": "16.67ms",
            "operation": "render"
        ]
        
        let testError = NSError(domain: "Test", code: 456, userInfo: [NSLocalizedDescriptionKey: "Context error"])
        
        // When
        logger.logErrorWithContext("Detailed error", context: context, error: testError)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 1, "Should capture 1 error log with context")
        XCTAssertEqual(logs[0].category, "Error", "Log category should be Error")
        XCTAssertEqual(logs[0].level, .error, "Log level should be error")
        XCTAssertTrue(logs[0].message.contains("Detailed error"), "Should contain error message")
        XCTAssertTrue(logs[0].message.contains("Context:"), "Should contain context section")
        XCTAssertTrue(logs[0].message.contains("frame: 1234"), "Should contain frame context")
        XCTAssertTrue(logs[0].message.contains("Domain: Test"), "Should contain error domain")
        XCTAssertTrue(logs[0].message.contains("Code: 456"), "Should contain error code")
    }
    
    // MARK: - Ray Tracing Logs
    
    func test_LogRayTracing_whenCalled_expectLogged() {
        // When
        logger.logRayTracing("Traced 1M rays", level: .info)
        logger.logRayTracing("Bounce count: 5", level: .debug)
        logger.logRayTracing("Sample count: 4", level: .info)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 3, "Should capture 3 ray tracing logs")
        XCTAssertEqual(logs[0].category, "RayTracing", "First log category should be RayTracing")
        XCTAssertTrue(logs.contains { $0.message == "Traced 1M rays" }, "Should contain ray count log")
    }
    
    // MARK: - Geometry Logs
    
    func test_LogGeometry_whenCalled_expectLogged() {
        // When
        logger.logGeometry("Created sphere with 64 segments", level: .info)
        logger.logGeometry("Generated 1000 vertices", level: .debug)
        logger.logGeometry("Geometry optimization complete", level: .info)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 3, "Should capture 3 geometry logs")
        XCTAssertEqual(logs[0].category, "Geometry", "First log category should be Geometry")
        XCTAssertTrue(logs.contains { $0.message.contains("sphere") }, "Should contain sphere creation log")
    }
    
    // MARK: - Static Methods
    
    func test_StaticMethods_whenCalled_expectLogged() {
        // When
        Logger.rendering("Static rendering log")
        Logger.audio("Static audio log")
        Logger.input("Static input log")
        Logger.memory("Static memory log")
        Logger.clock("Static clock log")
        Logger.performance("Static performance log")
        Logger.error("Static error log")
        Logger.rayTracing("Static ray tracing log")
        Logger.geometry("Static geometry log")
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 9, "Should capture 9 static method logs")
        XCTAssertTrue(logs.contains { $0.message == "Static rendering log" && $0.category == "Rendering" }, "Should contain static rendering log")
        XCTAssertTrue(logs.contains { $0.message == "Static audio log" && $0.category == "Audio" }, "Should contain static audio log")
        XCTAssertTrue(logs.contains { $0.message == "Static error log" && $0.category == "Error" }, "Should contain static error log")
    }
    
    // MARK: - Performance Timing
    
    func test_Timer_whenStartedAndEnded_expectMeasured() {
        // Given
        let label = "TestOperation"
        
        // When
        let startTime = logger.startTimer(label: label)
        Thread.sleep(forTimeInterval: 0.001)
        logger.endTimer(label: label, startTime: startTime)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 1, "Should capture 1 performance log from timer")
        XCTAssertEqual(logs[0].category, "Performance", "Log category should be Performance")
        XCTAssertTrue(logs[0].message.contains(label), "Log should contain timer label")
        XCTAssertTrue(logs[0].message.contains("ms"), "Log should contain time in milliseconds")
    }
    
    func test_MeasureTime_whenCalled_expectMeasured() {
        // Given
        let label = "BlockOperation"
        
        // When
        let result = logger.measureTime(label) {
            return 42
        }
        
        // Then
        XCTAssertEqual(result, 42, "Block should return result")
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 1, "Should capture 1 performance log from measureTime")
        XCTAssertTrue(logs[0].message.contains(label), "Log should contain block label")
    }
    
    // MARK: - Memory Usage
    
    func test_LogMemoryUsage_whenCalled_expectLogged() {
        // When
        logger.logMemoryUsage()
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 1, "Should capture 1 memory log")
        XCTAssertEqual(logs[0].category, "Memory", "Log category should be Memory")
        XCTAssertTrue(logs[0].message.contains("Current memory:"), "Log should contain memory usage")
        XCTAssertTrue(logs[0].message.contains("B") || logs[0].message.contains("KB") || logs[0].message.contains("MB"), "Log should contain memory unit")
    }
    
    // MARK: - Frame Logging
    
    func test_LogFrame_whenCalled_expectLogged() {
        // When
        // Call logFrame multiple times - it will log when 1 second has passed
        // Since lastLogTime starts at 0, first call will log immediately with count=1
        logger.logFrame()
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertGreaterThanOrEqual(logs.count, 1, "Should capture at least 1 FPS log")
        let fpsLogs = logs.filter { $0.category == "Performance" && $0.message.contains("FPS:") }
        XCTAssertGreaterThanOrEqual(fpsLogs.count, 1, "Should have at least one FPS log")
        if let fpsLog = fpsLogs.first {
            XCTAssertTrue(fpsLog.message.contains("FPS:"), "FPS log should contain FPS prefix")
        }
        
        // Test that frame counter increments
        logger.clearCapturedLogs()
        // Wait a bit to ensure next log happens
        Thread.sleep(forTimeInterval: 1.1)
        for _ in 0..<60 {
            logger.logFrame()
        }
        
        let logs2 = logger.getCapturedLogs()
        let fpsLogs2 = logs2.filter { $0.category == "Performance" && $0.message.contains("FPS:") }
        XCTAssertGreaterThanOrEqual(fpsLogs2.count, 1, "Should log FPS after waiting and counting frames")
    }
    
    // MARK: - Conditional Logging
    
    func test_LogIf_whenConditionTrue_expectLogged() {
        // Given
        let condition = true
        
        // When
        logger.logIf(condition, "Condition true", category: OSLog.default, level: .info)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 1, "Should capture 1 log when condition is true")
        XCTAssertEqual(logs[0].message, "Condition true", "Log message should match")
    }
    
    func test_LogIf_whenConditionFalse_expectNotLogged() {
        // Given
        let condition = false
        
        // When
        logger.logIf(condition, "Should not log", category: OSLog.default, level: .info)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 0, "Should not capture any logs when condition is false")
    }
    
    // MARK: - Batch Logging
    
    func test_BatchLogging_whenMultipleMessages_expectAllLogged() {
        // Given
        let messages = [
            "Message 1",
            "Message 2",
            "Message 3"
        ]
        
        // When
        logger.logBatch(messages, category: OSLog.default, level: .info)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 3, "Should capture all 3 batch messages")
        XCTAssertEqual(logs[0].message, "Message 1", "First message should match")
        XCTAssertEqual(logs[1].message, "Message 2", "Second message should match")
        XCTAssertEqual(logs[2].message, "Message 3", "Third message should match")
    }
    
    // MARK: - Log Levels
    
    func test_LogLevels_whenDifferentLevels_expectAppropriate() {
        // When
        logger.log("Debug message", category: OSLog.default, level: .debug)
        logger.log("Info message", category: OSLog.default, level: .info)
        logger.log("Warning message", category: OSLog.default, level: .warning)
        logger.log("Error message", category: OSLog.default, level: .error)
        logger.log("Fault message", category: OSLog.default, level: .fault)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 5, "Should capture all 5 log levels")
        XCTAssertTrue(logs.contains { $0.message == "Debug message" && $0.level == .debug }, "Should contain debug log")
        XCTAssertTrue(logs.contains { $0.message == "Info message" && $0.level == .info }, "Should contain info log")
        XCTAssertTrue(logs.contains { $0.message == "Warning message" && $0.level == .warning }, "Should contain warning log")
        XCTAssertTrue(logs.contains { $0.message == "Error message" && $0.level == .error }, "Should contain error log")
        XCTAssertTrue(logs.contains { $0.message == "Fault message" && $0.level == .fault }, "Should contain fault log")
    }
    
    // MARK: - Production Mode
    
    func test_ProductionMode_whenEnabled_expectOnlyErrors() {
        // Given
        logger.clearCapturedLogs()
        logger.isProduction = true
        
        // When
        logger.log("Debug should not log", category: OSLog.default, level: .debug)
        logger.log("Info should not log", category: OSLog.default, level: .info)
        logger.log("Warning should not log", category: OSLog.default, level: .warning)
        logger.log("Error should log", category: OSLog.default, level: .error)
        logger.log("Fault should log", category: OSLog.default, level: .fault)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 2, "Should only capture error and fault logs in production mode")
        XCTAssertTrue(logs.contains { $0.message == "Error should log" && $0.level == .error }, "Should contain error log")
        XCTAssertTrue(logs.contains { $0.message == "Fault should log" && $0.level == .fault }, "Should contain fault log")
        XCTAssertFalse(logs.contains { $0.message == "Debug should not log" }, "Should not contain debug log")
        XCTAssertFalse(logs.contains { $0.message == "Info should not log" }, "Should not contain info log")
        XCTAssertFalse(logs.contains { $0.message == "Warning should not log" }, "Should not contain warning log")
        
        // Reset
        logger.isProduction = false
    }
    
    // MARK: - Debug Mode Filtering
    
    func test_DebugMode_whenDisabled_expectNoDebugLogs() {
        // Given
        logger.clearCapturedLogs()
        logger.isDebug = false
        
        // When
        logger.log("Debug should not log", category: OSLog.default, level: .debug)
        logger.log("Info should log", category: OSLog.default, level: .info)
        logger.log("Warning should log", category: OSLog.default, level: .warning)
        logger.log("Error should log", category: OSLog.default, level: .error)
        
        // Then
        let logs = logger.getCapturedLogs()
        XCTAssertEqual(logs.count, 3, "Should only capture 3 logs (no debug)")
        XCTAssertFalse(logs.contains { $0.message == "Debug should not log" }, "Should not contain debug log")
        XCTAssertTrue(logs.contains { $0.message == "Info should log" }, "Should contain info log")
        XCTAssertTrue(logs.contains { $0.message == "Warning should log" }, "Should contain warning log")
        XCTAssertTrue(logs.contains { $0.message == "Error should log" }, "Should contain error log")
        
        // Reset
        logger.isDebug = true
    }
}
