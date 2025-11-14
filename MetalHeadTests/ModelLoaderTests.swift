import XCTest
import Metal
import MetalKit
import ModelIO
import AppKit
@testable import MetalHeadEngine

@MainActor
final class ModelLoaderTests: XCTestCase {
    
    var device: MTLDevice!
    var modelLoader: ModelLoader!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Metal not available"])
        }
        self.device = device
        self.modelLoader = ModelLoader(device: device)
    }
    
    override func tearDownWithError() throws {
        modelLoader = nil
        device = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Model Loading Tests
    
    func testModelLoaderInitialization() {
        XCTAssertNotNil(modelLoader)
        // ModelLoader should be initialized with device
        XCTAssertNotNil(device)
    }
    
    func testLoadTextureFromBundle() throws {
        // Create a test image programmatically
        let testImageURL = createTestImage()
        defer {
            try? FileManager.default.removeItem(at: testImageURL)
        }
        
        let texture = try modelLoader.loadTexture(from: testImageURL)
        
        XCTAssertNotNil(texture)
        XCTAssertEqual(texture.width, 256)
        XCTAssertEqual(texture.height, 256)
    }
    
    func testLoadPBRMaterial() throws {
        let testAlbedoURL = createTestImage()
        defer {
            try? FileManager.default.removeItem(at: testAlbedoURL)
        }
        
        let material = try modelLoader.loadPBRMaterial(baseColor: testAlbedoURL)
        
        XCTAssertNotNil(material.baseColorTexture)
        XCTAssertEqual(material.baseColor, SIMD4<Float>(1, 1, 1, 1))
    }
    
    func testLoadPBRMaterialWithAllTextures() throws {
        let testAlbedoURL = createTestImage(name: "albedo")
        let testNormalURL = createTestImage(name: "normal")
        let testRoughnessURL = createTestImage(name: "roughness")
        let testMetallicURL = createTestImage(name: "metallic")
        
        defer {
            [testAlbedoURL, testNormalURL, testRoughnessURL, testMetallicURL].forEach {
                try? FileManager.default.removeItem(at: $0)
            }
        }
        
        let material = try modelLoader.loadPBRMaterial(
            baseColor: testAlbedoURL,
            normal: testNormalURL,
            roughness: testRoughnessURL,
            metallic: testMetallicURL
        )
        
        XCTAssertNotNil(material.baseColorTexture)
        XCTAssertNotNil(material.normalTexture)
        XCTAssertNotNil(material.roughnessTexture)
        XCTAssertNotNil(material.metallicTexture)
    }
    
    // MARK: - Cache Tests
    
    func testMeshCache() {
        let cacheStats = modelLoader.getCacheStats()
        
        XCTAssertEqual(cacheStats.count, 0)
        XCTAssertEqual(cacheStats.totalVertices, 0)
    }
    
    func testClearCache() throws {
        let testImageURL = createTestImage()
        defer {
            try? FileManager.default.removeItem(at: testImageURL)
        }
        
        // Load a texture to populate cache
        _ = try modelLoader.loadTexture(from: testImageURL)
        
        modelLoader.clearCache()
        
        let cacheStats = modelLoader.getCacheStats()
        XCTAssertEqual(cacheStats.count, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(name: String = "test") -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testImageURL = tempDir.appendingPathComponent("\(name).png")
        
        // Create a simple 256x256 test image using AppKit
        let size = NSSize(width: 256, height: 256)
        let image = NSImage(size: size)
        
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            try? pngData.write(to: testImageURL)
        }
        
        return testImageURL
    }
}

