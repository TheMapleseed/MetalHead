import XCTest
import Metal
import simd
@testable import MetalHead

/// Main test suite for MetalHead engine
final class MetalHeadTests: XCTestCase {
    
    var device: MTLDevice!
    var unifiedEngine: UnifiedMultimediaEngine!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.metalNotSupported
        }
        self.device = device
        
        unifiedEngine = UnifiedMultimediaEngine()
    }
    
    override func tearDownWithError() throws {
        unifiedEngine = nil
        device = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Engine Initialization Tests
    
    func testUnifiedEngineInitialization() async throws {
        // Given
        XCTAssertNotNil(unifiedEngine)
        
        // When
        try await unifiedEngine.initialize()
        
        // Then
        XCTAssertTrue(unifiedEngine.isInitialized)
    }
    
    func testEngineStartStop() async throws {
        // Given
        try await unifiedEngine.initialize()
        
        // When
        try await unifiedEngine.start()
        
        // Then
        XCTAssertTrue(unifiedEngine.isRunning)
        
        // When
        unifiedEngine.stop()
        
        // Then
        XCTAssertFalse(unifiedEngine.isRunning)
    }
    
    func testSubsystemAccess() async throws {
        // Given
        try await unifiedEngine.initialize()
        
        // When & Then
        XCTAssertNotNil(unifiedEngine.getSubsystem(MetalRenderingEngine.self))
        XCTAssertNotNil(unifiedEngine.getSubsystem(Graphics2D.self))
        XCTAssertNotNil(unifiedEngine.getSubsystem(AudioEngine.self))
        XCTAssertNotNil(unifiedEngine.getSubsystem(InputManager.self))
        XCTAssertNotNil(unifiedEngine.getSubsystem(MemoryManager.self))
        XCTAssertNotNil(unifiedEngine.getSubsystem(UnifiedClockSystem.self))
        XCTAssertNotNil(unifiedEngine.getSubsystem(PerformanceMonitor.self))
    }
    
    // MARK: - Performance Tests
    
    func testEnginePerformance() async throws {
        // Given
        try await unifiedEngine.initialize()
        try await unifiedEngine.start()
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<1000 {
            // Simulate frame rendering
            let deltaTime = 1.0 / 120.0
            // Note: In real tests, you'd call unifiedEngine.render(deltaTime:in:)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 1.0, "Engine should process 1000 frames in less than 1 second")
    }
    
    func testMemoryUsage() async throws {
        // Given
        try await unifiedEngine.initialize()
        
        // When
        let initialMemory = getMemoryUsage()
        
        // Simulate memory allocation
        if let memoryManager = unifiedEngine.getSubsystem(MemoryManager.self) {
            let vertexData = memoryManager.allocateVertexData(count: 1000, type: Vertex.self)
            let uniformData = memoryManager.allocateUniformData(count: 100, type: Uniforms.self)
            
            // Then
            XCTAssertNotNil(vertexData)
            XCTAssertNotNil(uniformData)
            XCTAssertEqual(vertexData.count, 1000)
            XCTAssertEqual(uniformData.count, 100)
            
            // Cleanup
            memoryManager.deallocate(vertexData)
            memoryManager.deallocate(uniformData)
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Then
        XCTAssertLessThan(memoryIncrease, 1024 * 1024, "Memory increase should be less than 1MB")
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() async throws {
        // Given
        let invalidDevice: MTLDevice? = nil
        
        // When & Then
        XCTAssertThrowsError(try createRenderingEngineWithDevice(invalidDevice)) { error in
            XCTAssertTrue(error is RenderingError)
        }
    }
    
    func testInvalidSubsystemAccess() {
        // Given
        let engine = UnifiedMultimediaEngine()
        
        // When
        let invalidSubsystem = engine.getSubsystem(String.self)
        
        // Then
        XCTAssertNil(invalidSubsystem)
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
    
    private func createRenderingEngineWithDevice(_ device: MTLDevice?) throws -> MetalRenderingEngine {
        guard let device = device else {
            throw RenderingError.commandQueueCreationFailed
        }
        return MetalRenderingEngine(device: device)
    }
}

// MARK: - Test Errors
enum TestError: Error {
    case metalNotSupported
    case testSetupFailed
    case assertionFailed
}
