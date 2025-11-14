import XCTest
import Metal
@testable import MetalHeadEngine

/// Test configuration and utilities
final class TestConfiguration {
    
    // MARK: - Test Constants
    
    static let performanceThreshold: TimeInterval = 0.1
    static let memoryThreshold: UInt64 = 1024 * 1024 // 1MB
    static let frameRateThreshold: Double = 60.0
    static let latencyThreshold: TimeInterval = 0.016 // 16ms
    static let defaultTimeout: TimeInterval = 10.0 // 10 seconds per test
    static let asyncTimeout: TimeInterval = 5.0 // 5 seconds for async operations
    
    static func withTimeout<T>(seconds: TimeInterval, operation: () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TestError.assertionFailed
            }
            // Add actual operation
            group.addTask {
                try await operation()
            }
            // Return first completed
            let result = try await group.next()
            group.cancelAll()
            return result!
        }
    }
    
    // MARK: - Test Data
    
    static func createTestVertices(count: Int) -> [Vertex] {
        return (0..<count).map { i in
            Vertex(
                position: SIMD3<Float>(Float(i), Float(i), Float(i)),
                color: SIMD4<Float>(1, 0, 0, 1)
            )
        }
    }
    
    static func createTestUniforms(count: Int) -> [Uniforms] {
        return (0..<count).map { i in
            Uniforms(
                modelMatrix: matrix_identity_float4x4,
                viewMatrix: matrix_identity_float4x4,
                projectionMatrix: matrix_identity_float4x4,
                time: Float(i)
            )
        }
    }
    
    static func createTestAudioData(count: Int) -> [Float] {
        return (0..<count).map { i in
            Float(i) * 0.1
        }
    }
    
    // MARK: - Test Utilities
    
    static func measureExecutionTime<T>(_ block: () throws -> T) rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let endTime = CFAbsoluteTimeGetCurrent()
        return (result, endTime - startTime)
    }
    
    static func measureExecutionTime<T>(_ block: () async throws -> T) async rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let endTime = CFAbsoluteTimeGetCurrent()
        return (result, endTime - startTime)
    }
    
    static func createTestDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.metalNotSupported
        }
        return device
    }
    
    static func createTestEngine() async throws -> UnifiedMultimediaEngine {
        let engine = UnifiedMultimediaEngine()
        try await engine.initialize()
        return engine
    }
    
    // MARK: - Performance Assertions
    
    static func assertPerformance<T>(_ block: () throws -> T, threshold: TimeInterval = performanceThreshold) throws -> T {
        let (result, time) = try measureExecutionTime(block)
        XCTAssertLessThan(time, threshold, "Operation should complete within \(threshold) seconds")
        return result
    }
    
    static func assertPerformance<T>(_ block: () async throws -> T, threshold: TimeInterval = performanceThreshold) async throws -> T {
        let (result, time) = try await measureExecutionTime(block)
        XCTAssertLessThan(time, threshold, "Operation should complete within \(threshold) seconds")
        return result
    }
    
    // MARK: - Memory Assertions
    
    static func assertMemoryUsage(_ initialMemory: UInt64, _ finalMemory: UInt64, threshold: UInt64 = memoryThreshold) {
        let memoryIncrease = finalMemory - initialMemory
        XCTAssertLessThan(memoryIncrease, threshold, "Memory increase should be less than \(threshold) bytes")
    }
    
    // MARK: - Error Assertions
    
    static func assertThrowsError<T>(_ block: () throws -> T, errorType: Error.Type) {
        XCTAssertThrowsError(try block()) { error in
            XCTAssertTrue(error is errorType, "Error should be of type \(errorType)")
        }
    }
    
    static func assertThrowsError<T>(_ block: () async throws -> T, errorType: Error.Type) async {
        do {
            _ = try await block()
            XCTFail("Expected error of type \(errorType)")
        } catch {
            XCTAssertTrue(error is errorType, "Error should be of type \(errorType)")
        }
    }
}

// MARK: - Test Extensions

extension XCTestCase {
    
    func assertPerformance<T>(_ block: () throws -> T, threshold: TimeInterval = TestConfiguration.performanceThreshold) throws -> T {
        return try TestConfiguration.assertPerformance(block, threshold: threshold)
    }
    
    func assertPerformance<T>(_ block: () async throws -> T, threshold: TimeInterval = TestConfiguration.performanceThreshold) async throws -> T {
        return try await TestConfiguration.assertPerformance(block, threshold: threshold)
    }
    
    func assertMemoryUsage(_ initialMemory: UInt64, _ finalMemory: UInt64, threshold: UInt64 = TestConfiguration.memoryThreshold) {
        TestConfiguration.assertMemoryUsage(initialMemory, finalMemory, threshold: threshold)
    }
    
    func assertThrowsError<T>(_ block: () throws -> T, errorType: Error.Type) {
        TestConfiguration.assertThrowsError(block, errorType: errorType)
    }
    
    func assertThrowsError<T>(_ block: () async throws -> T, errorType: Error.Type) async {
        await TestConfiguration.assertThrowsError(block, errorType: errorType)
    }
}

// MARK: - Test Errors

enum TestError: Error, Equatable {
    case metalNotSupported
    case testSetupFailed
    case assertionFailed
    case performanceTestFailed
    case memoryTestFailed
    case threadSafetyTestFailed
}

// MARK: - Test Mock Objects

class MockRenderingEngine: MetalRenderingEngine {
    var renderCallCount = 0
    var lastDeltaTime: CFTimeInterval = 0
    
    override func render(deltaTime: CFTimeInterval, in view: MTKView) {
        renderCallCount += 1
        lastDeltaTime = deltaTime
    }
}

class MockAudioEngine: AudioEngine {
    var playCallCount = 0
    var stopCallCount = 0
    var volumeSetCount = 0
    var lastVolume: Float = 0
    
    override func play() {
        playCallCount += 1
        super.play()
    }
    
    override func stop() {
        stopCallCount += 1
        super.stop()
    }
    
    override func setVolume(_ volume: Float) {
        volumeSetCount += 1
        lastVolume = volume
        super.setVolume(volume)
    }
}

class MockInputManager: InputManager {
    var keyPressedCallCount = 0
    var mouseButtonPressedCallCount = 0
    var actionPressedCallCount = 0
    
    override func isKeyPressed(_ keyCode: UInt16) -> Bool {
        keyPressedCallCount += 1
        return super.isKeyPressed(keyCode)
    }
    
    override func isMouseButtonPressed(_ button: MouseButton) -> Bool {
        mouseButtonPressedCallCount += 1
        return super.isMouseButtonPressed(button)
    }
    
    override func isActionPressed(_ actionName: String) -> Bool {
        actionPressedCallCount += 1
        return super.isActionPressed(actionName)
    }
}

class MockMemoryManager: MemoryManager {
    var allocationCount = 0
    var deallocationCount = 0
    var lastAllocatedSize = 0
    
    override func allocateVertexData<T>(count: Int, type: T.Type) -> AllocatedMemory<T> {
        allocationCount += 1
        lastAllocatedSize = count
        return super.allocateVertexData(count: count, type: type)
    }
    
    override func deallocate<T>(_ allocatedMemory: AllocatedMemory<T>) {
        deallocationCount += 1
        super.deallocate(allocatedMemory)
    }
}

class MockClockSystem: UnifiedClockSystem {
    var startCallCount = 0
    var stopCallCount = 0
    var pauseCallCount = 0
    var resumeCallCount = 0
    
    override func start() {
        startCallCount += 1
        super.start()
    }
    
    override func stop() {
        stopCallCount += 1
        super.stop()
    }
    
    override func pause() {
        pauseCallCount += 1
        super.pause()
    }
    
    override func resume() {
        resumeCallCount += 1
        super.resume()
    }
}
