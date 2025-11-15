import Metal
import MetalKit
import simd
import Foundation
import AppKit

/// Advanced texture management with caching, mipmap generation, and resource optimization
@MainActor
public class TextureManager {
    
    // MARK: - Properties
    private let device: MTLDevice
    private var textureLoader: MTKTextureLoader
    private var textureCache: [String: MTLTexture] = [:]
    private var textureReferences: [String: Int] = [:]
    
    // MARK: - Initialization
    public init(device: MTLDevice) {
        self.device = device
        self.textureLoader = MTKTextureLoader(device: device)
    }
    
    // MARK: - Public Interface
    
    /// Load texture from URL with automatic caching
    public func loadTexture(from url: URL,
                           generateMipmaps: Bool = true,
                           options: [MTKTextureLoader.Option: Any]? = nil) throws -> MTLTexture {
        
        let cacheKey = url.path
        
        // Check cache
        if let cached = textureCache[cacheKey] {
            textureReferences[cacheKey, default: 0] += 1
            return cached
        }
        
        // Load texture
        let defaultOptions: [MTKTextureLoader.Option: Any] = [
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
            .generateMipmaps: NSNumber(value: generateMipmaps)
        ]
        
        let mergedOptions = defaultOptions.merging(options ?? [:]) { _, new in new }
        
        let texture = try textureLoader.newTexture(URL: url, options: mergedOptions)
        
        // Cache texture
        textureCache[cacheKey] = texture
        textureReferences[cacheKey] = 1
        
        print("Loaded and cached texture: \(url.lastPathComponent)")
        
        return texture
    }
    
    /// Load texture from NSImage data
    public func loadTexture(from image: NSImage,
                           name: String,
                           generateMipmaps: Bool = true) throws -> MTLTexture {
        
        let cacheKey = name
        
        // Check cache
        if let cached = textureCache[cacheKey] {
            textureReferences[cacheKey, default: 0] += 1
            return cached
        }
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw TextureError.imageConversionFailed
        }
        
        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
            .generateMipmaps: NSNumber(value: generateMipmaps)
        ]
        
        let texture = try textureLoader.newTexture(cgImage: cgImage, options: options)
        
        textureCache[cacheKey] = texture
        textureReferences[cacheKey] = 1
        
        return texture
    }
    
    /// Create texture from raw pixel data
    public func createTexture(width: Int,
                             height: Int,
                             pixelFormat: MTLPixelFormat,
                             data: UnsafeRawPointer? = nil,
                             name: String? = nil) throws -> MTLTexture {
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .private
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw TextureError.creationFailed
        }
        
        if let data = data {
            let bytesPerRow = width * 4 // Assuming RGBA
            texture.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                             size: MTLSize(width: width, height: height, depth: 1)),
                           mipmapLevel: 0,
                           withBytes: data,
                           bytesPerRow: bytesPerRow)
        }
        
        if let name = name {
            textureCache[name] = texture
            textureReferences[name] = 1
        }
        
        return texture
    }
    
    /// Release texture reference
    public func releaseTexture(key: String) {
        if let count = textureReferences[key], count > 1 {
            textureReferences[key] = count - 1
        } else {
            textureCache.removeValue(forKey: key)
            textureReferences.removeValue(forKey: key)
            print("Released texture: \(key)")
        }
    }
    
    /// Get texture from cache
    public func getTexture(key: String) -> MTLTexture? {
        return textureCache[key]
    }
    
    /// Clear all cached textures
    public func clearCache() {
        textureCache.removeAll()
        textureReferences.removeAll()
        print("Texture cache cleared")
    }
    
    /// Get cache statistics
    public func getCacheStats() -> (count: Int, totalMemory: Int) {
        var totalMemory = 0
        
        for (_, texture) in textureCache {
            let bytesPerPixel = getBytesPerPixel(pixelFormat: texture.pixelFormat)
            let memory = texture.width * texture.height * bytesPerPixel
            totalMemory += memory
        }
        
        return (textureCache.count, totalMemory)
    }
    
    // MARK: - Private Methods
    
    private func getBytesPerPixel(pixelFormat: MTLPixelFormat) -> Int {
        switch pixelFormat {
        case .bgra8Unorm, .rgba8Unorm:
            return 4
        case .rgba16Float:
            return 8
        case .r32Float:
            return 4
        case .depth32Float:
            return 4
        default:
            return 4
        }
    }
}

// MARK: - Errors
public enum TextureError: Error, Sendable {
    case imageConversionFailed
    case creationFailed
    case loadFailed
}

