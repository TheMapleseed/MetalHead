import XCTest
import Metal
@testable import MetalHeadEngine

/// Performance tests for MetalHead engine
final class PerformanceTests: XCTestCase {
    
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
    
    // MARK: - Engine Performance Tests
    
    func testEngineInitializationPerformance() async throws {
        // Given
        let iterations = 10
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for _ in 0..<iterations {
            let engine = UnifiedMultimediaEngine()
            try await engine.initialize()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        let averageTime = executionTime / Double(iterations)
        
        // Then
        XCTAssertLessThan(averageTime, 1.0, "Engine initialization should be fast")
    }
    
    func testEngineStartStopPerformance() async throws {
        // Given
        try await unifiedEngine.initialize()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for _ in 0..<100 {
            try await unifiedEngine.start()
            unifiedEngine.stop()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        let averageTime = executionTime / 100.0
        
        // Then
        XCTAssertLessThan(averageTime, 0.01, "Engine start/stop should be fast")
    }
    
    // MARK: - Rendering Performance Tests
    
    func testRenderingEnginePerformance() async throws {
        // Given
        try await unifiedEngine.initialize()
        guard let renderingEngine = unifiedEngine.getSubsystem(MetalRenderingEngine.self) else {
            XCTFail("Rendering engine not available")
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for _ in 0..<1000 {
            // Simulate rendering operations
            renderingEngine.toggle3DMode()
            renderingEngine.toggle2DMode()
            renderingEngine.updateMousePosition(SIMD2<Float>(100, 200))
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.1, "Rendering operations should be fast")
    }
    
    func testGraphics2DPerformance() async throws {
        // Given
        try await unifiedEngine.initialize()
        guard let graphics2D = unifiedEngine.getSubsystem(Graphics2D.self) else {
            XCTFail("Graphics2D not available")
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for i in 0..<1000 {
            let position = SIMD2<Float>(Float(i), Float(i))
            let size = SIMD2<Float>(50, 50)
            let color = SIMD4<Float>(1, 0, 0, 1)
            
            graphics2D.drawRectangle(at: position, size: size, color: color)
            graphics2D.drawCircle(at: position, radius: 25, color: color)
            graphics2D.drawLine(from: position, to: position + SIMD2<Float>(100, 100), thickness: 2, color: color)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.1, "2D graphics operations should be fast")
    }
    
    // MARK: - Audio Performance Tests
    
    func testAudioEnginePerformance() async throws {
        // Given
        try await unifiedEngine.initialize()
        guard let audioEngine = unifiedEngine.getSubsystem(AudioEngine.self) else {
            XCTFail("Audio engine not available")
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for _ in 0..<1000 {
            audioEngine.getAudioLevel()
            audioEngine.getSpectrumData()
            audioEngine.setVolume(Float.random(in: 0...1))
            audioEngine.setSpatialPosition(SIMD3<Float>(
                Float.random(in: -10...10),
                Float.random(in: -10...10),
                Float.random(in: -10...10)
            ))
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.1, "Audio operations should be fast")
    }
    
    // MARK: - Input Performance Tests
    
    func testInputManagerPerformance() async throws {
        // Given
        try await unifiedEngine.initialize()
        guard let inputManager = unifiedEngine.getSubsystem(InputManager.self) else {
            XCTFail("Input manager not available")
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for _ in 0..<1000 {
            inputManager.isKeyPressed(49)
            inputManager.isMouseButtonPressed(.left)
            inputManager.isActionPressed("move_forward")
            inputManager.setMouseSensitivity(Float.random(in: 0.1...10))
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.1, "Input operations should be fast")
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryAllocationPerformance() async throws {
        // Given
        try await unifiedEngine.initialize()
        guard let memoryManager = unifiedEngine.getSubsystem(MemoryManager.self) else {
            XCTFail("Memory manager not available")
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        var allocatedMemories: [AllocatedMemory<Vertex>] = []
        
        for _ in 0..<100 {
            let allocatedMemory = memoryManager.allocateVertexData(count: 1000, type: Vertex.self)
            allocatedMemories.append(allocatedMemory)
        }
        
        for allocatedMemory in allocatedMemories {
            memoryManager.deallocate(allocatedMemory)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.1, "Memory allocation should be fast")
    }
    
    func testMemoryAccessPerformance() async throws {
        // Given
        try await unifiedEngine.initialize()
        guard let memoryManager = unifiedEngine.getSubsystem(MemoryManager.self) else {
            XCTFail("Memory manager not available")
            return
        }
        
        let allocatedMemory = memoryManager.allocateVertexData(count: 10000, type: Vertex.self)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for i in 0..<allocatedMemory.count {
            allocatedMemory[i] = Vertex(
                position: SIMD3<Float>(Float(i), Float(i), Float(i)),
                color: SIMD4<Float>(1, 0, 0, 1)
            )
        }
        
        for i in 0..<allocatedMemory.count {
            _ = allocatedMemory[i]
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.1, "Memory access should be fast")
        
        // Cleanup
        memoryManager.deallocate(allocatedMemory)
    }
    
    // MARK: - Clock System Performance Tests
    
    func testClockSystemPerformance() async throws {
        // Given
        try await unifiedEngine.initialize()
        guard let clockSystem = unifiedEngine.getSubsystem(UnifiedClockSystem.self) else {
            XCTFail("Clock system not available")
            return
        }
        
        clockSystem.start()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for _ in 0..<1000 {
            _ = clockSystem.getCurrentTime()
            _ = clockSystem.getCurrentFrame()
            _ = clockSystem.getCompensatedTime(for: .rendering)
            _ = clockSystem.getCompensatedTime(for: .audio)
            _ = clockSystem.getCompensatedTime(for: .input)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.1, "Clock system operations should be fast")
        
        clockSystem.stop()
    }
    
    // MARK: - Performance Monitor Tests
    
    func testPerformanceMonitorPerformance() async throws {
        // Given
        try await unifiedEngine.initialize()
        guard let performanceMonitor = unifiedEngine.getSubsystem(PerformanceMonitor.self) else {
            XCTFail("Performance monitor not available")
            return
        }
        
        performanceMonitor.startMonitoring()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for _ in 0..<1000 {
            performanceMonitor.recordFrameTime(1.0 / 120.0)
            _ = performanceMonitor.getMemoryUsage()
            _ = performanceMonitor.getCPUUsage()
            _ = performanceMonitor.getGPUUtilization()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.1, "Performance monitoring should be fast")
        
        performanceMonitor.stopMonitoring()
    }
    
    // MARK: - Integration Performance Tests
    
    func testFullEnginePerformance() async throws {
        // Given
        try await unifiedEngine.initialize()
        try await unifiedEngine.start()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for _ in 0..<100 {
            // Simulate full engine operations
            if let renderingEngine = unifiedEngine.getSubsystem(MetalRenderingEngine.self) {
                renderingEngine.toggle3DMode()
            }
            
            if let audioEngine = unifiedEngine.getSubsystem(AudioEngine.self) {
                audioEngine.setVolume(Float.random(in: 0...1))
            }
            
            if let inputManager = unifiedEngine.getSubsystem(InputManager.self) {
                inputManager.isKeyPressed(49)
            }
            
            if let memoryManager = unifiedEngine.getSubsystem(MemoryManager.self) {
                let allocatedMemory = memoryManager.allocateVertexData(count: 100, type: Vertex.self)
                memoryManager.deallocate(allocatedMemory)
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.5, "Full engine operations should be fast")
        
        unifiedEngine.stop()
    }
    
    // MARK: - Memory Leak Tests
    
    func testMemoryLeaks() async throws {
        // Given
        try await unifiedEngine.initialize()
        guard let memoryManager = unifiedEngine.getSubsystem(MemoryManager.self) else {
            XCTFail("Memory manager not available")
            return
        }
        
        let initialMemory = memoryManager.getMemoryReport()
        
        // When
        for _ in 0..<1000 {
            let allocatedMemory = memoryManager.allocateVertexData(count: 100, type: Vertex.self)
            memoryManager.deallocate(allocatedMemory)
        }
        
        // Then
        let finalMemory = memoryManager.getMemoryReport()
        let memoryIncrease = finalMemory.totalAllocated - initialMemory.totalAllocated
        
        XCTAssertLessThan(memoryIncrease, 1024 * 1024, "Memory should not leak significantly")
    }
    
    // MARK: - Thread Safety Tests
    
    func testThreadSafety() async throws {
        // Given
        try await unifiedEngine.initialize()
        try await unifiedEngine.start()
        
        let expectation = XCTestExpectation(description: "Thread safety test")
        expectation.expectedFulfillmentCount = 10
        
        // When
        for _ in 0..<10 {
            Task {
                if let renderingEngine = unifiedEngine.getSubsystem(MetalRenderingEngine.self) {
                    renderingEngine.toggle3DMode()
                }
                
                if let audioEngine = unifiedEngine.getSubsystem(AudioEngine.self) {
                    audioEngine.setVolume(Float.random(in: 0...1))
                }
                
                if let inputManager = unifiedEngine.getSubsystem(InputManager.self) {
                    inputManager.isKeyPressed(49)
                }
                
                expectation.fulfill()
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        
        unifiedEngine.stop()
    }
}
