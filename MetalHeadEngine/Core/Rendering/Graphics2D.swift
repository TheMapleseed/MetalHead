import Metal
import MetalKit
import simd
import Foundation

/// 2D graphics system with Metal optimization
/// Handles sprite rendering, text, and 2D shapes
@MainActor
public class Graphics2D: ObservableObject {
    // MARK: - Properties
    private let device: MTLDevice
    private var commandQueue: MTLCommandQueue!
    private var renderPipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!
    private var textureCache: [String: MTLTexture] = [:]
    
    // 2D Scene data
    private var sprites: [Sprite2D] = []
    private var textElements: [Text2D] = []
    private var shapes: [Shape2D] = []
    
    // Rendering state
    private var currentTexture: MTLTexture?
    private var currentColor: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1)
    
    // MARK: - Initialization
    public init(device: MTLDevice) {
        self.device = device
    }
    
    // MARK: - Public Interface
    public func initialize() async throws {
        try setupCommandQueue()
        try setupPipeline()
        try setupBuffers()
        print("Graphics2D initialized successfully")
    }
    
    public func render(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // Render sprites
        for sprite in sprites {
            renderSprite(sprite, encoder: renderEncoder)
        }
        
        // Render shapes
        for shape in shapes {
            renderShape(shape, encoder: renderEncoder)
        }
        
        // Render text
        for text in textElements {
            renderText(text, encoder: renderEncoder)
        }
        
        renderEncoder.endEncoding()
    }
    
    public func drawSprite(at position: SIMD2<Float>, size: SIMD2<Float>, texture: MTLTexture?, color: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1)) {
        let sprite = Sprite2D(position: position, size: size, texture: texture, color: color)
        sprites.append(sprite)
    }
    
    public func drawRectangle(at position: SIMD2<Float>, size: SIMD2<Float>, color: SIMD4<Float>) {
        let shape = Shape2D(position: position, size: size, color: color)
        shapes.append(shape)
    }
    
    public func drawCircle(at center: SIMD2<Float>, radius: Float, color: SIMD4<Float>) {
        let size = SIMD2<Float>(radius * 2, radius * 2)
        let position = center - SIMD2<Float>(radius, radius)
        let shape = Shape2D(position: position, size: size, color: color)
        shapes.append(shape)
    }
    
    public func drawLine(from start: SIMD2<Float>, to end: SIMD2<Float>, thickness: Float, color: SIMD4<Float>) {
        let direction = end - start
        let length = length(direction)
        let angle = atan2(direction.y, direction.x)
        
        let size = SIMD2<Float>(length, thickness)
        let position = start
        
        let shape = Shape2D(position: position, size: size, color: color, rotation: angle)
        shapes.append(shape)
    }
    
    public func drawText(_ text: String, at position: SIMD2<Float>, size: Float, color: SIMD4<Float>) {
        let textElement = Text2D(text: text, position: position, size: size, color: color)
        textElements.append(textElement)
    }
    
    public func loadTexture(from imageData: Data, name: String) throws -> MTLTexture {
        if let cachedTexture = textureCache[name] {
            return cachedTexture
        }
        
        guard let image = NSImage(data: imageData) else {
            throw Graphics2DError.imageLoadFailed
        }
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw Graphics2DError.imageLoadFailed
        }
        
        let textureLoader = MTKTextureLoader(device: device)
        let texture = try textureLoader.newTexture(cgImage: cgImage, options: [
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ])
        
        textureCache[name] = texture
        return texture
    }
    
    public func setColor(_ color: SIMD4<Float>) {
        currentColor = color
    }
    
    public func clear() {
        sprites.removeAll()
        shapes.removeAll()
        textElements.removeAll()
    }
    
    // MARK: - Private Methods
    private func setupCommandQueue() throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw Graphics2DError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue
    }
    
    private func setupPipeline() throws {
        guard let library = device.makeDefaultLibrary() else {
            throw Graphics2DError.libraryCreationFailed
        }
        
        let vertexFunction = library.makeFunction(name: "vertex_2d_main")
        let fragmentFunction = library.makeFunction(name: "fragment_2d_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.rasterSampleCount = 4
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[2].format = .float4
        vertexDescriptor.attributes[2].offset = MemoryLayout<SIMD2<Float>>.stride * 2
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex2D>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            self.renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            throw Graphics2DError.pipelineCreationFailed
        }
    }
    
    private func setupBuffers() throws {
        let vertices: [Vertex2D] = [
            Vertex2D(position: SIMD2<Float>(-1, -1), texCoord: SIMD2<Float>(0, 1), color: SIMD4<Float>(1, 1, 1, 1)),
            Vertex2D(position: SIMD2<Float>( 1, -1), texCoord: SIMD2<Float>(1, 1), color: SIMD4<Float>(1, 1, 1, 1)),
            Vertex2D(position: SIMD2<Float>( 1,  1), texCoord: SIMD2<Float>(1, 0), color: SIMD4<Float>(1, 1, 1, 1)),
            Vertex2D(position: SIMD2<Float>(-1,  1), texCoord: SIMD2<Float>(0, 0), color: SIMD4<Float>(1, 1, 1, 1))
        ]
        
        let indices: [UInt16] = [0, 1, 2, 2, 3, 0]
        
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex2D>.stride, options: []) else {
            throw Graphics2DError.bufferCreationFailed
        }
        self.vertexBuffer = vertexBuffer
        
        guard let indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: []) else {
            throw Graphics2DError.bufferCreationFailed
        }
        self.indexBuffer = indexBuffer
    }
    
    private func renderSprite(_ sprite: Sprite2D, encoder: MTLRenderCommandEncoder) {
        if let texture = sprite.texture {
            encoder.setFragmentTexture(texture, index: 0)
        }
        
        updateVertexData(for: sprite)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: 6, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
    }
    
    private func renderShape(_ shape: Shape2D, encoder: MTLRenderCommandEncoder) {
        encoder.setFragmentTexture(nil, index: 0)
        updateVertexData(for: shape)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: 6, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
    }
    
    private func renderText(_ text: Text2D, encoder: MTLRenderCommandEncoder) {
        if let texture = text.texture {
            encoder.setFragmentTexture(texture, index: 0)
        }
        
        updateVertexData(for: text)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: 6, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
    }
    
    private func updateVertexData(for drawable: Drawable2D) {
        let vertices: [Vertex2D] = [
            Vertex2D(position: drawable.topLeft, texCoord: SIMD2<Float>(0, 1), color: drawable.color),
            Vertex2D(position: drawable.topRight, texCoord: SIMD2<Float>(1, 1), color: drawable.color),
            Vertex2D(position: drawable.bottomRight, texCoord: SIMD2<Float>(1, 0), color: drawable.color),
            Vertex2D(position: drawable.bottomLeft, texCoord: SIMD2<Float>(0, 0), color: drawable.color)
        ]
        
        let vertexPointer = vertexBuffer.contents().bindMemory(to: Vertex2D.self, capacity: 4)
        for (index, vertex) in vertices.enumerated() {
            vertexPointer[index] = vertex
        }
    }
}

// MARK: - Data Structures
public protocol Drawable2D {
    var position: SIMD2<Float> { get set }
    var size: SIMD2<Float> { get set }
    var color: SIMD4<Float> { get set }
    var rotation: Float { get set }
    
    var topLeft: SIMD2<Float> { get }
    var topRight: SIMD2<Float> { get }
    var bottomLeft: SIMD2<Float> { get }
    var bottomRight: SIMD2<Float> { get }
}

public class Sprite2D: Drawable2D {
    public var position: SIMD2<Float>
    public var size: SIMD2<Float>
    public var color: SIMD4<Float>
    public var rotation: Float
    public var texture: MTLTexture?
    
    public init(position: SIMD2<Float>, size: SIMD2<Float>, texture: MTLTexture?, color: SIMD4<Float>, rotation: Float = 0) {
        self.position = position
        self.size = size
        self.color = color
        self.rotation = rotation
        self.texture = texture
    }
    
    public var topLeft: SIMD2<Float> {
        let halfSize = size * 0.5
        let rotated = rotatePoint(SIMD2<Float>(-halfSize.x, halfSize.y), by: rotation)
        return position + rotated
    }
    
    public var topRight: SIMD2<Float> {
        let halfSize = size * 0.5
        let rotated = rotatePoint(SIMD2<Float>(halfSize.x, halfSize.y), by: rotation)
        return position + rotated
    }
    
    public var bottomLeft: SIMD2<Float> {
        let halfSize = size * 0.5
        let rotated = rotatePoint(SIMD2<Float>(-halfSize.x, -halfSize.y), by: rotation)
        return position + rotated
    }
    
    public var bottomRight: SIMD2<Float> {
        let halfSize = size * 0.5
        let rotated = rotatePoint(SIMD2<Float>(halfSize.x, -halfSize.y), by: rotation)
        return position + rotated
    }
    
    private func rotatePoint(_ point: SIMD2<Float>, by angle: Float) -> SIMD2<Float> {
        let cos = cosf(angle)
        let sin = sinf(angle)
        return SIMD2<Float>(
            point.x * cos - point.y * sin,
            point.x * sin + point.y * cos
        )
    }
}

public class Shape2D: Drawable2D {
    public var position: SIMD2<Float>
    public var size: SIMD2<Float>
    public var color: SIMD4<Float>
    public var rotation: Float
    
    public init(position: SIMD2<Float>, size: SIMD2<Float>, color: SIMD4<Float>, rotation: Float = 0) {
        self.position = position
        self.size = size
        self.color = color
        self.rotation = rotation
    }
    
    public var topLeft: SIMD2<Float> {
        let halfSize = size * 0.5
        let rotated = rotatePoint(SIMD2<Float>(-halfSize.x, halfSize.y), by: rotation)
        return position + rotated
    }
    
    public var topRight: SIMD2<Float> {
        let halfSize = size * 0.5
        let rotated = rotatePoint(SIMD2<Float>(halfSize.x, halfSize.y), by: rotation)
        return position + rotated
    }
    
    public var bottomLeft: SIMD2<Float> {
        let halfSize = size * 0.5
        let rotated = rotatePoint(SIMD2<Float>(-halfSize.x, -halfSize.y), by: rotation)
        return position + rotated
    }
    
    public var bottomRight: SIMD2<Float> {
        let halfSize = size * 0.5
        let rotated = rotatePoint(SIMD2<Float>(halfSize.x, -halfSize.y), by: rotation)
        return position + rotated
    }
    
    private func rotatePoint(_ point: SIMD2<Float>, by angle: Float) -> SIMD2<Float> {
        let cos = cosf(angle)
        let sin = sinf(angle)
        return SIMD2<Float>(
            point.x * cos - point.y * sin,
            point.x * sin + point.y * cos
        )
    }
}

public class Text2D: Drawable2D {
    public var position: SIMD2<Float>
    public var size: SIMD2<Float>
    public var color: SIMD4<Float>
    public var rotation: Float
    public var text: String
    public var texture: MTLTexture?
    
    public init(text: String, position: SIMD2<Float>, size: Float, color: SIMD4<Float>) {
        self.text = text
        self.position = position
        self.size = SIMD2<Float>(size * Float(text.count) * 0.6, size)
        self.color = color
        self.rotation = 0
    }
    
    public var topLeft: SIMD2<Float> {
        let halfSize = size * 0.5
        let rotated = rotatePoint(SIMD2<Float>(-halfSize.x, halfSize.y), by: rotation)
        return position + rotated
    }
    
    public var topRight: SIMD2<Float> {
        let halfSize = size * 0.5
        let rotated = rotatePoint(SIMD2<Float>(halfSize.x, halfSize.y), by: rotation)
        return position + rotated
    }
    
    public var bottomLeft: SIMD2<Float> {
        let halfSize = size * 0.5
        let rotated = rotatePoint(SIMD2<Float>(-halfSize.x, -halfSize.y), by: rotation)
        return position + rotated
    }
    
    public var bottomRight: SIMD2<Float> {
        let halfSize = size * 0.5
        let rotated = rotatePoint(SIMD2<Float>(halfSize.x, -halfSize.y), by: rotation)
        return position + rotated
    }
    
    private func rotatePoint(_ point: SIMD2<Float>, by angle: Float) -> SIMD2<Float> {
        let cos = cosf(angle)
        let sin = sinf(angle)
        return SIMD2<Float>(
            point.x * cos - point.y * sin,
            point.x * sin + point.y * cos
        )
    }
}

public struct Vertex2D {
    public var position: SIMD2<Float>
    public var texCoord: SIMD2<Float>
    public var color: SIMD4<Float>
    
    public init(position: SIMD2<Float>, texCoord: SIMD2<Float>, color: SIMD4<Float>) {
        self.position = position
        self.texCoord = texCoord
        self.color = color
    }
}

// MARK: - Errors
public enum Graphics2DError: Error {
    case commandQueueCreationFailed
    case libraryCreationFailed
    case pipelineCreationFailed
    case bufferCreationFailed
    case imageLoadFailed
}
