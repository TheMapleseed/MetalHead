import XCTest
import Metal
@testable import MetalHead

@MainActor
final class OffscreenRendererTests: XCTestCase {
    
    var device: MTLDevice!
    var offscreenRenderer: OffscreenRenderer!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTestError(.formattingError)
        }
        self.device = device
        self.offscreenRenderer = OffscreenRenderer(device: device)
    }
    
    override func tearDownWithError() throws {
        offscreenRenderer = nil
        device = nil
        try super.tearDownWithError()
    }
    
    func testOffscreenRendererInitialization() {
        XCTAssertNotNil(offscreenRenderer)
    }
    
    func testInitializeOffscreenRenderer() async throws {
        try offscreenRenderer.initialize()
        XCTAssertTrue(true)
    }
    
    func testCreateRenderTarget() async throws {
        try offscreenRenderer.initialize()
        
        let texture = try offscreenRenderer.createRenderTarget(name: "test",
                                                               width: 512,
                                                               height: 512)
        
        XCTAssertNotNil(texture)
        XCTAssertEqual(texture.width, 512)
        XCTAssertEqual(texture.height, 512)
    }
    
    func testGetRenderTarget() async throws {
        try offscreenRenderer.initialize()
        
        let _ = try offscreenRenderer.createRenderTarget(name: "test", width: 256, height: 256)
        let texture = offscreenRenderer.getRenderTarget(name: "test")
        
        XCTAssertNotNil(texture)
    }
}

