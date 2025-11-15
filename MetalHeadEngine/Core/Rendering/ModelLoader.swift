import Metal
import MetalKit
import ModelIO
import simd
import Foundation

/// 3D model loading using MetalKit and Model I/O
/// Provides seamless integration for loading OBJ, USDZ, and other 3D formats
@MainActor
public class ModelLoader {
    
    // MARK: - Properties
    private let device: MTLDevice
    private var meshCache: [String: MTKMesh] = [:]
    private let textureLoader: MTKTextureLoader
    
    // MARK: - Initialization
    public init(device: MTLDevice) {
        self.device = device
        self.textureLoader = MTKTextureLoader(device: device)
    }
    
    // MARK: - Public Interface
    
    /// Loads a 3D model from a file path (supports OBJ, USDZ, and more)
    public func loadModel(from url: URL) throws -> MTKMesh {
        let key = url.path
        
        // Check cache
        if let cachedMesh = meshCache[key] {
            return cachedMesh
        }
        
        // Create Model I/O asset
        let asset = MDLAsset(url: url,
                            vertexDescriptor: nil,
                            bufferAllocator: MTKMeshBufferAllocator(device: device))
        
        guard let object = asset.object(at: 0) as? MDLMesh else {
            throw ModelLoaderError.invalidModel
        }
        
        // Convert to MetalKit mesh
        let mesh = try MTKMesh(mesh: object, device: device)
        
        // Cache the mesh
        meshCache[key] = mesh
        
        print("Loaded model: \(url.lastPathComponent) (\(mesh.vertexCount) vertices, \(mesh.submeshes.count) submeshes)")
        
        return mesh
    }
    
    /// Loads a model from resource bundle
    public func loadModel(name: String, extension ext: String = "obj") throws -> MTKMesh {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw ModelLoaderError.fileNotFound
        }
        
        return try loadModel(from: url)
    }
    
    /// Loads a texture from file (expands on MTKTextureLoader)
    public func loadTexture(from url: URL, options: [MTKTextureLoader.Option: Any]? = nil) throws -> MTLTexture {
        let defaultOptions: [MTKTextureLoader.Option: Any] = [
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.shared.rawValue),
            .generateMipmaps: NSNumber(value: true)
        ]
        
        let mergedOptions = defaultOptions.merging(options ?? [:]) { _, new in new }
        
        return try textureLoader.newTexture(URL: url, options: mergedOptions)
    }
    
    /// Creates a material from PBR textures (Albedo, Normal, Roughness, etc.)
    public func loadPBRMaterial(baseColor: URL? = nil,
                               normal: URL? = nil,
                               roughness: URL? = nil,
                               metallic: URL? = nil) throws -> PBRMaterial {
        
        var material = PBRMaterial()
        
        if let baseColorURL = baseColor {
            material.baseColorTexture = try? loadTexture(from: baseColorURL)
        }
        
        if let normalURL = normal {
            material.normalTexture = try? loadTexture(from: normalURL, options: [
                .generateMipmaps: NSNumber(value: false)
            ])
        }
        
        if let roughnessURL = roughness {
            material.roughnessTexture = try? loadTexture(from: roughnessURL, options: [
                .generateMipmaps: NSNumber(value: false)
            ])
        }
        
        if let metallicURL = metallic {
            material.metallicTexture = try? loadTexture(from: metallicURL, options: [
                .generateMipmaps: NSNumber(value: false)
            ])
        }
        
        return material
    }
    
    /// Clears the mesh cache
    public func clearCache() {
        meshCache.removeAll()
    }
    
    /// Gets cache stats
    public func getCacheStats() -> (count: Int, totalVertices: Int) {
        var totalVertices = 0
        for mesh in meshCache.values {
            totalVertices += mesh.vertexCount
        }
        return (meshCache.count, totalVertices)
    }
}

// MARK: - Data Structures
public struct PBRMaterial {
    public var baseColorTexture: MTLTexture?
    public var normalTexture: MTLTexture?
    public var roughnessTexture: MTLTexture?
    public var metallicTexture: MTLTexture?
    public var baseColor: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1)
    public var roughness: Float = 0.5
    public var metallic: Float = 0.0
    
    public init() {}
}

// MARK: - Error Types
public enum ModelLoaderError: Error, Sendable {
    case fileNotFound
    case invalidModel
    case loadFailed
}

