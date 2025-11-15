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
        try await computeShaderManager.initialize()
        // If we get here, initialization succeeded
        XCTAssertTrue(true)
    }
}

