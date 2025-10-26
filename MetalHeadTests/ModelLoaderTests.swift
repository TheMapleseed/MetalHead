import XCTest
import Metal
import MetalKit
import ModelIO
@testable import MetalHead

@MainActor
final class ModelLoaderTests: XCTestCase {
    
    var device: MTLDevice!
    var modelLoader: ModelLoader!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTestError(.formattingError)
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
        XCTAssertNotNil(modelLoader.value(forKey: "device") as? MTLDevice)
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
        
        // Create a simple 256x256 test image
        let size = CGSize(width: 256, height: 256)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        if let imageData = image.pngData() {
            try? imageData.write(to: testImageURL)
        }
        
        return testImageURL
    }
}

