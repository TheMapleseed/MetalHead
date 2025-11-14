import XCTest
import Metal
import MetalKit
import AppKit
@testable import MetalHeadEngine

@MainActor
final class TextureManagerTests: XCTestCase {
    
    var device: MTLDevice!
    var textureManager: TextureManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Metal not available"])
        }
        self.device = device
        self.textureManager = TextureManager(device: device)
    }
    
    override func tearDownWithError() throws {
        textureManager = nil
        device = nil
        try super.tearDownWithError()
    }
    
    func testTextureManagerInitialization() {
        XCTAssertNotNil(textureManager)
    }
    
    func testCreateTextureFromData() throws {
        let width = 256
        let height = 256
        let pixelCount = width * height
        var pixels = [UInt8](repeating: 255, count: pixelCount * 4)
        
        let texture = try textureManager.createTexture(width: width,
                                                       height: height,
                                                       pixelFormat: .bgra8Unorm,
                                                       data: pixels.withUnsafeMutableBytes { $0.baseAddress },
                                                       name: "testTexture")
        
        XCTAssertNotNil(texture)
        XCTAssertEqual(texture.width, width)
        XCTAssertEqual(texture.height, height)
    }
    
    func testTextureCache() throws {
        let width = 128
        let height = 128
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        
        _ = try textureManager.createTexture(width: width, height: height, pixelFormat: .bgra8Unorm,
                                             data: pixels.withUnsafeMutableBytes { $0.baseAddress }, name: "cached")
        
        let cachedTexture = textureManager.getTexture(key: "cached")
        XCTAssertNotNil(cachedTexture)
        
        let stats = textureManager.getCacheStats()
        XCTAssertEqual(stats.count, 1)
    }
    
    func testReleaseTexture() throws {
        let width = 64
        let height = 64
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        
        _ = try textureManager.createTexture(width: width, height: height, pixelFormat: .bgra8Unorm,
                                             data: pixels.withUnsafeMutableBytes { $0.baseAddress }, name: "toRelease")
        
        textureManager.releaseTexture(key: "toRelease")
        
        let releasedTexture = textureManager.getTexture(key: "toRelease")
        XCTAssertNil(releasedTexture)
    }
}

