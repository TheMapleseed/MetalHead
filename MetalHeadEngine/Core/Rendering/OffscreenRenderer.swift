import Metal
import MetalKit
import simd
import Foundation

/// Manages offscreen rendering to textures for post-processing and multipass effects
@MainActor
public class OffscreenRenderer {
    
    // MARK: - Properties
    private let device: MTLDevice
    private var commandQueue: MTLCommandQueue!
    private var renderTargets: [String: MTLTexture] = [:]
    private var renderPassDescriptors: [String: MTLRenderPassDescriptor] = [:]
    
    // MARK: - Initialization
    public init(device: MTLDevice) {
        self.device = device
    }
    
    // MARK: - Public Interface
    
    /// Initialize the offscreen renderer
    public func initialize() throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw OffscreenRenderError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue
        print("OffscreenRenderer initialized successfully")
    }
    
    /// Create a render target texture
    public func createRenderTarget(name: String,
                                   width: Int,
                                   height: Int,
                                   pixelFormat: MTLPixelFormat = .bgra8Unorm) throws -> MTLTexture {
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw OffscreenRenderError.textureCreationFailed
        }
        
        renderTargets[name] = texture
        
        // Create render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        renderPassDescriptors[name] = renderPassDescriptor
        
        return texture
    }
    
    /// Get render target by name
    public func getRenderTarget(name: String) -> MTLTexture? {
        return renderTargets[name]
    }
    
    /// Get render pass descriptor by name
    public func getRenderPassDescriptor(name: String) -> MTLRenderPassDescriptor? {
        return renderPassDescriptors[name]
    }
    
    /// Render a scene to a render target
    public func renderToTexture(name: String,
                               renderFunction: (MTLRenderCommandEncoder) -> Void) throws {
        
        guard let renderPassDescriptor = renderPassDescriptors[name] else {
            throw OffscreenRenderError.renderTargetNotFound(name)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw OffscreenRenderError.commandBufferCreationFailed
        }
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            throw OffscreenRenderError.encoderCreationFailed
        }
        
        renderFunction(encoder)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    /// Blit texture to another texture (for post-processing)
    public func blitTexture(source: MTLTexture, destination: MTLTexture) throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw OffscreenRenderError.commandBufferCreationFailed
        }
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw OffscreenRenderError.encoderCreationFailed
        }
        
        blitEncoder.copy(from: source,
                        sourceSlice: 0,
                        sourceLevel: 0,
                        sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                        sourceSize: MTLSize(width: source.width, height: source.height, depth: 1),
                        to: destination,
                        destinationSlice: 0,
                        destinationLevel: 0,
                        destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    /// Clear render targets
    public func clearRenderTargets() {
        renderTargets.removeAll()
        renderPassDescriptors.removeAll()
    }
}

// MARK: - Errors
public enum OffscreenRenderError: Error, Sendable {
    case commandQueueCreationFailed
    case commandBufferCreationFailed
    case encoderCreationFailed
    case textureCreationFailed
    case renderTargetNotFound(String)
}

