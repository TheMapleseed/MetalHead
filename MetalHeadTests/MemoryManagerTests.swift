import XCTest
import Metal
@testable import MetalHeadEngine

/// Unit tests for MemoryManager
final class MemoryManagerTests: XCTestCase {
    
    var device: MTLDevice!
    var memoryManager: MemoryManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.metalNotSupported
        }
        self.device = device
        
        memoryManager = MemoryManager(device: device)
    }
    
    override func tearDownWithError() throws {
        memoryManager = nil
        device = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testMemoryManagerInitialization() {
        // Given & When
        let manager = MemoryManager(device: device)
        
        // Then
        XCTAssertNotNil(manager)
        XCTAssertEqual(manager.totalAllocatedMemory, 0)
        XCTAssertEqual(manager.activeAllocations, 0)
        XCTAssertEqual(manager.memoryFragmentation, 0.0)
    }
    
    // MARK: - Vertex Data Allocation Tests
    
    func testVertexDataAllocation() {
        // Given
        let count = 1000
        let type = Vertex.self
        
        // When
        let allocatedMemory = memoryManager.allocateVertexData(count: count, type: type)
        
        // Then
        XCTAssertNotNil(allocatedMemory)
        XCTAssertEqual(allocatedMemory.count, count)
        XCTAssertTrue(memoryManager.activeAllocations > 0)
    }
    
    func testVertexDataAccess() {
        // Given
        let count = 100
        let allocatedMemory = memoryManager.allocateVertexData(count: count, type: Vertex.self)
        
        // When
        for i in 0..<count {
            allocatedMemory[i] = Vertex(
                position: SIMD3<Float>(Float(i), Float(i), Float(i)),
                color: SIMD4<Float>(1, 0, 0, 1)
            )
        }
        
        // Then
        for i in 0..<count {
            XCTAssertEqual(allocatedMemory[i].position.x, Float(i))
            XCTAssertEqual(allocatedMemory[i].color.x, 1.0)
        }
    }
    
    func testVertexDataDeallocation() {
        // Given
        let allocatedMemory = memoryManager.allocateVertexData(count: 100, type: Vertex.self)
        let initialAllocations = memoryManager.activeAllocations
        
        // When
        memoryManager.deallocate(allocatedMemory)
        
        // Then
        XCTAssertEqual(memoryManager.activeAllocations, initialAllocations - 1)
    }
    
    // MARK: - Uniform Data Allocation Tests
    
    func testUniformDataAllocation() {
        // Given
        let count = 100
        let type = Uniforms.self
        
        // When
        let allocatedMemory = memoryManager.allocateUniformData(count: count, type: type)
        
        // Then
        XCTAssertNotNil(allocatedMemory)
        XCTAssertEqual(allocatedMemory.count, count)
    }
    
    func testUniformDataAccess() {
        // Given
        let count = 10
        let allocatedMemory = memoryManager.allocateUniformData(count: count, type: Uniforms.self)
        
        // When
        for i in 0..<count {
            allocatedMemory[i] = Uniforms(
                modelMatrix: matrix_identity_float4x4,
                viewMatrix: matrix_identity_float4x4,
                projectionMatrix: matrix_identity_float4x4,
                time: Float(i)
            )
        }
        
        // Then
        for i in 0..<count {
            XCTAssertEqual(allocatedMemory[i].time, Float(i))
        }
    }
    
    // MARK: - Audio Data Allocation Tests
    
    func testAudioDataAllocation() {
        // Given
        let count = 1024
        
        // When
        let allocatedMemory = memoryManager.allocateAudioData(count: count)
        
        // Then
        XCTAssertNotNil(allocatedMemory)
        XCTAssertEqual(allocatedMemory.count, count)
    }
    
    func testAudioDataAccess() {
        // Given
        let count = 100
        let allocatedMemory = memoryManager.allocateAudioData(count: count)
        
        // When
        for i in 0..<count {
            allocatedMemory[i] = Float(i) * 0.1
        }
        
        // Then
        for i in 0..<count {
            XCTAssertEqual(allocatedMemory[i], Float(i) * 0.1)
        }
    }
    
    // MARK: - Texture Data Allocation Tests
    
    func testTextureDataAllocation() {
        // Given
        let width = 256
        let height = 256
        let bytesPerPixel = 4
        
        // When
        let allocatedMemory = memoryManager.allocateTextureData(
            width: width,
            height: height,
            bytesPerPixel: bytesPerPixel
        )
        
        // Then
        XCTAssertNotNil(allocatedMemory)
        XCTAssertEqual(allocatedMemory.count, width * height * bytesPerPixel)
    }
    
    func testTextureDataAccess() {
        // Given
        let width = 64
        let height = 64
        let bytesPerPixel = 4
        let allocatedMemory = memoryManager.allocateTextureData(
            width: width,
            height: height,
            bytesPerPixel: bytesPerPixel
        )
        
        // When
        for i in 0..<allocatedMemory.count {
            allocatedMemory[i] = UInt8(i % 256)
        }
        
        // Then
        for i in 0..<allocatedMemory.count {
            XCTAssertEqual(allocatedMemory[i], UInt8(i % 256))
        }
    }
    
    // MARK: - Memory Pool Tests
    
    func testMetalBufferAllocation() {
        // Given
        let size = 1024
        let options: MTLResourceOptions = []
        
        // When
        let buffer = memoryManager.getMetalBuffer(size: size, options: options)
        
        // Then
        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer.length, size)
    }
    
    func testMetalBufferReturn() {
        // Given
        let buffer = memoryManager.getMetalBuffer(size: 1024, options: [])
        XCTAssertNotNil(buffer)
        
        // When
        memoryManager.returnMetalBuffer(buffer!)
        
        // Then (should not crash)
        XCTAssertTrue(true)
    }
    
    // MARK: - Memory Compaction Tests
    
    func testMemoryCompaction() {
        // Given
        let allocatedMemory1 = memoryManager.allocateVertexData(count: 100, type: Vertex.self)
        let allocatedMemory2 = memoryManager.allocateVertexData(count: 100, type: Vertex.self)
        memoryManager.deallocate(allocatedMemory1)
        memoryManager.deallocate(allocatedMemory2)
        
        // When
        memoryManager.compactMemory()
        
        // Then (should not crash)
        XCTAssertTrue(true)
    }
    
    // MARK: - Memory Report Tests
    
    func testMemoryReport() {
        // Given
        let allocatedMemory = memoryManager.allocateVertexData(count: 100, type: Vertex.self)
        
        // When
        let report = memoryManager.getMemoryReport()
        
        // Then
        XCTAssertNotNil(report)
        XCTAssertTrue(report.totalAllocated > 0)
        XCTAssertTrue(report.activeAllocations > 0)
        XCTAssertTrue(report.fragmentation >= 0.0)
        XCTAssertFalse(report.regionReports.isEmpty)
        
        // Cleanup
        memoryManager.deallocate(allocatedMemory)
    }
    
    // MARK: - Performance Tests
    
    func testAllocationPerformance() {
        // Given
        let iterations = 1000
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for _ in 0..<iterations {
            let allocatedMemory = memoryManager.allocateVertexData(count: 10, type: Vertex.self)
            memoryManager.deallocate(allocatedMemory)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 1.0, "Allocation should be fast")
    }
    
    func testLargeAllocationPerformance() {
        // Given
        let count = 10000
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        let allocatedMemory = memoryManager.allocateVertexData(count: count, type: Vertex.self)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.1, "Large allocation should be fast")
        
        // Cleanup
        memoryManager.deallocate(allocatedMemory)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidAllocation() {
        // Given
        let invalidCount = -1
        
        // When & Then (should not crash)
        let allocatedMemory = memoryManager.allocateVertexData(count: invalidCount, type: Vertex.self)
        XCTAssertEqual(allocatedMemory.count, 0)
    }
    
    func testZeroAllocation() {
        // Given
        let count = 0
        
        // When
        let allocatedMemory = memoryManager.allocateVertexData(count: count, type: Vertex.self)
        
        // Then
        XCTAssertEqual(allocatedMemory.count, 0)
    }
}
