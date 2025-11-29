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
    
    // Fullscreen quad for lighting pass
    private var fullscreenQuadBuffer: MTLBuffer!
    
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
        try createFullscreenQuad()
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
        
        // Set vertex buffer for fullscreen quad
        encoder.setVertexBuffer(fullscreenQuadBuffer, offset: 0, index: 0)
        
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
    
    private func createFullscreenQuad() throws {
        // Create fullscreen quad vertices for lighting pass
        // Using Vertex2D structure: position (float2), texCoord (float2), color (float4)
        struct FullscreenQuadVertex {
            var position: SIMD2<Float>
            var texCoord: SIMD2<Float>
            var color: SIMD4<Float>
        }
        
        let vertices: [FullscreenQuadVertex] = [
            FullscreenQuadVertex(position: SIMD2<Float>(-1, -1), texCoord: SIMD2<Float>(0, 1), color: SIMD4<Float>(1, 1, 1, 1)),
            FullscreenQuadVertex(position: SIMD2<Float>( 1, -1), texCoord: SIMD2<Float>(1, 1), color: SIMD4<Float>(1, 1, 1, 1)),
            FullscreenQuadVertex(position: SIMD2<Float>( 1,  1), texCoord: SIMD2<Float>(1, 0), color: SIMD4<Float>(1, 1, 1, 1)),
            FullscreenQuadVertex(position: SIMD2<Float>(-1, -1), texCoord: SIMD2<Float>(0, 1), color: SIMD4<Float>(1, 1, 1, 1)),
            FullscreenQuadVertex(position: SIMD2<Float>( 1,  1), texCoord: SIMD2<Float>(1, 0), color: SIMD4<Float>(1, 1, 1, 1)),
            FullscreenQuadVertex(position: SIMD2<Float>(-1,  1), texCoord: SIMD2<Float>(0, 0), color: SIMD4<Float>(1, 1, 1, 1))
        ]
        
        guard let buffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<FullscreenQuadVertex>.stride, options: []) else {
            throw DeferredRenderError.textureCreationFailed
        }
        fullscreenQuadBuffer = buffer
    }
    
    private func setupPipelineStates() throws {
        // Load Metal library from framework bundle
        let frameworkBundle = Bundle(for: type(of: self))
        let library: MTLLibrary
        
        if let metalLibURL = frameworkBundle.url(forResource: "default", withExtension: "metallib") {
            library = try device.makeLibrary(URL: metalLibURL)
        } else if let defaultLibrary = device.makeDefaultLibrary() {
            library = defaultLibrary
        } else {
            throw DeferredRenderError.libraryNotFound
        }
        
        // Setup G-Buffer pipeline (writes to multiple render targets)
        guard let gBufferVertexFunction = library.makeFunction(name: "gbuffer_vertex"),
              let gBufferFragmentFunction = library.makeFunction(name: "gbuffer_fragment") else {
            throw DeferredRenderError.libraryNotFound
        }
        
        let gBufferDescriptor = MTLRenderPipelineDescriptor()
        gBufferDescriptor.vertexFunction = gBufferVertexFunction
        gBufferDescriptor.fragmentFunction = gBufferFragmentFunction
        gBufferDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm // Albedo
        gBufferDescriptor.colorAttachments[1].pixelFormat = .rgba16Float // Normal
        gBufferDescriptor.depthAttachmentPixelFormat = .depth32Float
        gBufferDescriptor.rasterSampleCount = 1
        
        // Vertex descriptor for G-Buffer
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        gBufferDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            gBufferPipelineState = try device.makeRenderPipelineState(descriptor: gBufferDescriptor)
        } catch {
            throw DeferredRenderError.libraryNotFound
        }
        
        // Setup Lighting pipeline (fullscreen quad that reads G-Buffer)
        guard let lightingFragmentFunction = library.makeFunction(name: "lighting_fragment") else {
            throw DeferredRenderError.libraryNotFound
        }
        
        let lightingDescriptor = MTLRenderPipelineDescriptor()
        lightingDescriptor.vertexFunction = library.makeFunction(name: "vertex_2d_main")
        lightingDescriptor.fragmentFunction = lightingFragmentFunction
        lightingDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        lightingDescriptor.rasterSampleCount = 1
        
        // Vertex descriptor for fullscreen quad (using Vertex2D from Graphics2D)
        // Vertex2D has: position (float2), texCoord (float2), color (float4)
        let lightingVertexDescriptor = MTLVertexDescriptor()
        lightingVertexDescriptor.attributes[0].format = .float2
        lightingVertexDescriptor.attributes[0].offset = 0
        lightingVertexDescriptor.attributes[0].bufferIndex = 0
        lightingVertexDescriptor.attributes[1].format = .float2
        lightingVertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        lightingVertexDescriptor.attributes[1].bufferIndex = 0
        lightingVertexDescriptor.attributes[2].format = .float4
        lightingVertexDescriptor.attributes[2].offset = MemoryLayout<SIMD2<Float>>.stride * 2
        lightingVertexDescriptor.attributes[2].bufferIndex = 0
        lightingVertexDescriptor.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride * 2 + MemoryLayout<SIMD4<Float>>.stride
        lightingVertexDescriptor.layouts[0].stepRate = 1
        lightingVertexDescriptor.layouts[0].stepFunction = .perVertex
        
        lightingDescriptor.vertexDescriptor = lightingVertexDescriptor
        
        do {
            lightingPipelineState = try device.makeRenderPipelineState(descriptor: lightingDescriptor)
        } catch {
            throw DeferredRenderError.libraryNotFound
        }
        
        // Composition pipeline (optional - can reuse lighting or add post-processing)
        // For now, we'll use the same as lighting
        compositionPipelineState = lightingPipelineState
        
        print("Deferred rendering pipelines initialized successfully")
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

public struct DeferredMaterial: Sendable {
    public let albedo: SIMD3<Float>
    public let roughness: Float
    public let metallic: Float
    
    public init(albedo: SIMD3<Float>, roughness: Float, metallic: Float) {
        self.albedo = albedo
        self.roughness = roughness
        self.metallic = metallic
    }
}

public struct DeferredLight: Sendable {
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
public enum DeferredRenderError: Error, Sendable {
    case commandQueueCreationFailed
    case textureCreationFailed
    case encoderCreationFailed
    case libraryNotFound
}

