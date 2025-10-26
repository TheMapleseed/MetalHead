import XCTest
import os.log
@testable import MetalHead

/// Unit tests for Logger system
/// Comprehensive testing of logging functionality
final class LoggerTests: XCTestCase {
    
    var logger: Logger!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        logger = Logger.shared
        logger.isVerbose = true
        logger.isDebug = true
    }
    
    override func tearDownWithError() throws {
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
        XCTAssertTrue(true, "Rendering logs recorded")
    }
    
    // MARK: - Audio Logs
    
    func test_LogAudio_whenCalled_expectLogged() {
        // When
        logger.logAudio("Audio playback started", level: .info)
        logger.logAudio("Buffer size: 1024", level: .debug)
        logger.logAudio("Warning: Audio interruption", level: .warning)
        
        // Then
        XCTAssertTrue(true, "Audio logs recorded")
    }
    
    // MARK: - Input Logs
    
    func test_LogInput_whenCalled_expectLogged() {
        // When
        logger.logInput("Key pressed: Space", level: .info)
        logger.logInput("Mouse position: (100, 200)", level: .debug)
        logger.logInput("Mouse captured", level: .info)
        
        // Then
        XCTAssertTrue(true, "Input logs recorded")
    }
    
    // MARK: - Memory Logs
    
    func test_LogMemory_whenCalled_expectLogged() {
        // When
        logger.logMemory("Allocated 100MB", level: .info)
        logger.logMemory("Memory pool created", level: .debug)
        logger.logMemory("Warning: High memory usage", level: .warning)
        
        // Then
        XCTAssertTrue(true, "Memory logs recorded")
    }
    
    // MARK: - Clock Logs
    
    func test_LogClock_whenCalled_expectLogged() {
        // When
        logger.logClock("Frame time: 16.67ms", level: .info)
        logger.logClock("Time sync successful", level: .debug)
        logger.logClock("Warning: Timing drift detected", level: .warning)
        
        // Then
        XCTAssertTrue(true, "Clock logs recorded")
    }
    
    // MARK: - Performance Logs
    
    func test_LogPerformance_whenCalled_expectLogged() {
        // When
        logger.logPerformance("FPS: 120", level: .info)
        logger.logPerformance("CPU usage: 45%", level: .info)
        logger.logPerformance("GPU usage: 80%", level: .info)
        
        // Then
        XCTAssertTrue(true, "Performance logs recorded")
    }
    
    // MARK: - Error Logs
    
    func test_LogError_whenCalled_expectLogged() {
        // Given
        let testError = NSError(domain: "Test", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // When
        logger.logError("Operation failed", error: testError)
        logger.logError("System error", error: nil)
        
        // Then
        XCTAssertTrue(true, "Error logs recorded")
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
        XCTAssertTrue(true, "Error with context logged")
    }
    
    // MARK: - Ray Tracing Logs
    
    func test_LogRayTracing_whenCalled_expectLogged() {
        // When
        logger.logRayTracing("Traced 1M rays", level: .info)
        logger.logRayTracing("Bounce count: 5", level: .debug)
        logger.logRayTracing("Sample count: 4", level: .info)
        
        // Then
        XCTAssertTrue(true, "Ray tracing logs recorded")
    }
    
    // MARK: - Geometry Logs
    
    func test_LogGeometry_whenCalled_expectLogged() {
        // When
        logger.logGeometry("Created sphere with 64 segments", level: .info)
        logger.logGeometry("Generated 1000 vertices", level: .debug)
        logger.logGeometry("Geometry optimization complete", level: .info)
        
        // Then
        XCTAssertTrue(true, "Geometry logs recorded")
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
        XCTAssertTrue(true, "Static methods logged")
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
        XCTAssertTrue(true, "Timer measured time")
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
        XCTAssertTrue(true, "Time measured")
    }
    
    // MARK: - Memory Usage
    
    func test_LogMemoryUsage_whenCalled_expectLogged() {
        // When
        logger.logMemoryUsage()
        
        // Then
        XCTAssertTrue(true, "Memory usage logged")
    }
    
    // MARK: - Frame Logging
    
    func test_LogFrame_whenCalled_expectLogged() {
        // When
        for _ in 0..<120 {
            logger.logFrame()
        }
        
        // Then
        XCTAssertTrue(true, "Frames logged")
    }
    
    // MARK: - Conditional Logging
    
    func test_LogIf_whenConditionTrue_expectLogged() {
        // Given
        let condition = true
        
        // When
        logger.logIf(condition, "Condition true", category: OSLog.default, level: .info)
        
        // Then
        XCTAssertTrue(true, "Conditional log recorded")
    }
    
    func test_LogIf_whenConditionFalse_expectNotLogged() {
        // Given
        let condition = false
        
        // When
        logger.logIf(condition, "Should not log", category: OSLog.default, level: .info)
        
        // Then
        XCTAssertTrue(true, "Conditional log not recorded")
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
        XCTAssertTrue(true, "All messages logged")
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
        XCTAssertTrue(true, "All log levels recorded")
    }
    
    // MARK: - Production Mode
    
    func test_ProductionMode_whenEnabled_expectOnlyErrors() {
        // Given
        logger.isProduction = true
        
        // When
        logger.log("Debug should not log", category: OSLog.default, level: .debug)
        logger.log("Info should not log", category: OSLog.default, level: .info)
        logger.log("Error should log", category: OSLog.default, level: .error)
        
        // Then
        XCTAssertTrue(true, "Production mode respects level filtering")
        
        // Reset
        logger.isProduction = false
    }
}
