import XCTest
import Metal
import MetalKit
@testable import MetalHeadEngine

@MainActor
final class ComputeShaderManagerTests: XCTestCase {
    
    var device: MTLDevice!
    var computeShaderManager: ComputeShaderManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Metal not available"])
        }
        self.device = device
        self.computeShaderManager = ComputeShaderManager(device: device)
    }
    
    override func tearDownWithError() throws {
        computeShaderManager = nil
        device = nil
        try super.tearDownWithError()
    }
    
    func testComputeShaderManagerInitialization() {
        XCTAssertNotNil(computeShaderManager)
    }
    
    func testInitializeComputeShaderManager() async throws {
        // When & Then - should not throw
        XCTAssertNoThrow(try await computeShaderManager.initialize(), "Compute shader manager should initialize without error")
        
        // Verify we can dispatch shaders after initialization
        let dataSize = 1024 * MemoryLayout<Float>.size
        let data = UnsafeMutablePointer<Float>.allocate(capacity: 1024)
        defer { data.deallocate() }
        
        XCTAssertNoThrow(try computeShaderManager.dispatchShader(
            named: "compute_main",
            data: data,
            dataSize: dataSize,
            threadsPerGrid: MTLSize(width: 32, height: 32, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)
        ), "Should be able to dispatch shader after initialization")
    }
}

