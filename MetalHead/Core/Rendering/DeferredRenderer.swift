import Metal
import MetalKit
import simd
import Foundation

/// Implements deferred rendering pipeline for advanced lighting and effects
/// Uses multiple render passes: G-Buffer, Lighting, Composition
@MainActor
public class DeferredRenderer {
    
    // MARK: - Properties
    private let device: MTLDevice
    private var commandQueue: MTLCommandQueue!
    
    // G-Buffer textures (Geometry Buffer)
    private var gBufferAlbedo: MTLTexture!
    private var gBufferNormal: MTLTexture!
    private var gBufferDepth: MTLTexture!
    private var gBufferDepthStencil: MTLTexture!
    
    // Render targets
    private var lightingTarget: MTLTexture!
    private var finalTarget: MTLTexture!
    
    // Pipeline states
    private var gBufferPipelineState: MTLRenderPipelineState!
    private var lightingPipelineState: MTLRenderPipelineState!
    private var compositionPipelineState: MTLRenderPipelineState!
    
    // MARK: - Initialization
    public init(device: MTLDevice) {
        self.device = device
    }
    
    // MARK: - Public Interface
    
    /// Initialize the deferred renderer
    public func initialize(width: Int, height: Int) throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw DeferredRenderError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue
        
        try createGBuffer(width: width, height: height)
        try createLightingTarget(width: width, height: height)
        try setupPipelineStates()
        
        print("DeferredRenderer initialized successfully")
    }
    
    /// Update render target sizes
    public func updateSize(width: Int, height: Int) throws {
        try createGBuffer(width: width, height: height)
        try createLightingTarget(width: width, height: height)
    }
    
    /// Render G-Buffer pass (deferred rendering stage 1)
    public func renderGBuffer(commandBuffer: MTLCommandBuffer,
                             cameraViewMatrix: matrix_float4x4,
                             geometries: [DeferredGeometry]) throws {
        
        // Create G-Buffer render pass descriptor
        let gBufferPassDescriptor = MTLRenderPassDescriptor()
        gBufferPassDescriptor.colorAttachments[0].texture = gBufferAlbedo
        gBufferPassDescriptor.colorAttachments[0].loadAction = .clear
        gBufferPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        gBufferPassDescriptor.colorAttachments[1].texture = gBufferNormal
        gBufferPassDescriptor.colorAttachments[1].loadAction = .clear
        
        gBufferPassDescriptor.depthAttachment.texture = gBufferDepth
        gBufferPassDescriptor.depthAttachment.loadAction = .clear
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: gBufferPassDescriptor) else {
            throw DeferredRenderError.encoderCreationFailed
        }
        
        encoder.setRenderPipelineState(gBufferPipelineState)
        
        // Render geometries to G-Buffer
        for geometry in geometries {
            encoder.setVertexBuffer(geometry.vertexBuffer, offset: 0, index: 0)
            var material = geometry.material
            encoder.setFragmentBytes(&material, length: MemoryLayout<DeferredMaterial>.size, index: 0)
            
            if let indexBuffer = geometry.indexBuffer {
                encoder.drawIndexedPrimitives(type: .triangle,
                                             indexCount: geometry.indexCount,
                                             indexType: .uint32,
                                             indexBuffer: indexBuffer,
                                             indexBufferOffset: 0)
            } else {
                encoder.drawPrimitives(type: .triangle,
                                     vertexStart: 0,
                                     vertexCount: geometry.vertexCount)
            }
        }
        
        encoder.endEncoding()
    }
    
    /// Render lighting pass (deferred rendering stage 2)
    public func renderLighting(commandBuffer: MTLCommandBuffer,
                               lights: [DeferredLight]) throws {
        
        // Create lighting render pass descriptor
        let lightingPassDescriptor = MTLRenderPassDescriptor()
        lightingPassDescriptor.colorAttachments[0].texture = lightingTarget
        lightingPassDescriptor.colorAttachments[0].loadAction = .clear
        lightingPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: lightingPassDescriptor) else {
            throw DeferredRenderError.encoderCreationFailed
        }
        
        encoder.setRenderPipelineState(lightingPipelineState)
        
        // Set G-Buffer textures
        encoder.setFragmentTexture(gBufferAlbedo, index: 0)
        encoder.setFragmentTexture(gBufferNormal, index: 1)
        encoder.setFragmentTexture(gBufferDepth, index: 2)
        
        // Pass lights
        var lightCount = UInt32(lights.count)
        encoder.setFragmentBytes(&lightCount, length: MemoryLayout<UInt32>.size, index: 0)
        
        if !lights.isEmpty {
            var lightsArray = lights
            lightsArray.withUnsafeMutableBytes { buffer in
                if let baseAddress = buffer.baseAddress {
                    encoder.setFragmentBytes(baseAddress, length: lights.count * MemoryLayout<DeferredLight>.size, index: 1)
                }
            }
        }
        
        // Render fullscreen quad for lighting
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
    }
    
    /// Get the final lighting texture
    public func getLightingTexture() -> MTLTexture? {
        return lightingTarget
    }
    
    /// Get G-Buffer textures for debugging
    public func getGBufferAlbedo() -> MTLTexture? { return gBufferAlbedo }
    public func getGBufferNormal() -> MTLTexture? { return gBufferNormal }
    public func getGBufferDepth() -> MTLTexture? { return gBufferDepth }
    
    // MARK: - Private Methods
    
    private func createGBuffer(width: Int, height: Int) throws {
        // Albedo texture
        let albedoDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        albedoDescriptor.usage = [.renderTarget, .shaderRead]
        albedoDescriptor.storageMode = .private
        
        guard let albedo = device.makeTexture(descriptor: albedoDescriptor) else {
            throw DeferredRenderError.textureCreationFailed
        }
        gBufferAlbedo = albedo
        
        // Normal texture
        let normalDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: width,
            height: height,
            mipmapped: false
        )
        normalDescriptor.usage = [.renderTarget, .shaderRead]
        normalDescriptor.storageMode = .private
        
        guard let normal = device.makeTexture(descriptor: normalDescriptor) else {
            throw DeferredRenderError.textureCreationFailed
        }
        gBufferNormal = normal
        
        // Depth texture
        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        depthDescriptor.usage = [.renderTarget, .shaderRead]
        depthDescriptor.storageMode = .private
        
        guard let depth = device.makeTexture(descriptor: depthDescriptor) else {
            throw DeferredRenderError.textureCreationFailed
        }
        gBufferDepth = depth
    }
    
    private func createLightingTarget(width: Int, height: Int) throws {
        let lightingDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        lightingDescriptor.usage = [.renderTarget, .shaderRead]
        lightingDescriptor.storageMode = .private
        
        guard let lighting = device.makeTexture(descriptor: lightingDescriptor) else {
            throw DeferredRenderError.textureCreationFailed
        }
        lightingTarget = lighting
    }
    
    private func setupPipelineStates() throws {
        guard let library = device.makeDefaultLibrary() else {
            throw DeferredRenderError.libraryNotFound
        }
        
        // G-Buffer pipeline would be setup here
        // Lighting pipeline would be setup here
        // Composition pipeline would be setup here
        
        print("Deferred rendering pipelines would be setup here")
    }
}

// MARK: - Data Structures
public struct DeferredGeometry {
    public let vertexBuffer: MTLBuffer
    public let indexBuffer: MTLBuffer?
    public let vertexCount: Int
    public let indexCount: Int
    public let material: DeferredMaterial
    
    public init(vertexBuffer: MTLBuffer,
               indexBuffer: MTLBuffer?,
               vertexCount: Int,
               indexCount: Int,
               material: DeferredMaterial) {
        self.vertexBuffer = vertexBuffer
        self.indexBuffer = indexBuffer
        self.vertexCount = vertexCount
        self.indexCount = indexCount
        self.material = material
    }
}

public struct DeferredMaterial {
    public let albedo: SIMD3<Float>
    public let roughness: Float
    public let metallic: Float
    
    public init(albedo: SIMD3<Float>, roughness: Float, metallic: Float) {
        self.albedo = albedo
        self.roughness = roughness
        self.metallic = metallic
    }
}

public struct DeferredLight {
    public let position: SIMD3<Float>
    public let color: SIMD3<Float>
    public let intensity: Float
    public let radius: Float
    
    public init(position: SIMD3<Float>, color: SIMD3<Float>, intensity: Float, radius: Float) {
        self.position = position
        self.color = color
        self.intensity = intensity
        self.radius = radius
    }
}

// MARK: - Errors
public enum DeferredRenderError: Error {
    case commandQueueCreationFailed
    case textureCreationFailed
    case encoderCreationFailed
    case libraryNotFound
}

