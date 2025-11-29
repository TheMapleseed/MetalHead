import Metal
import MetalKit
import simd
import Foundation

/// Manages compute shader execution for GPU-accelerated computations
/// Provides high-level API for particle systems, audio visualization, and GPGPU operations
@MainActor
public class ComputeShaderManager {
    
    // MARK: - Properties
    private let device: MTLDevice
    private var commandQueue: MTLCommandQueue!
    private var computePipelineStates: [String: MTLComputePipelineState] = [:]
    private var computeBuffers: [String: MTLBuffer] = [:]
    
    // MARK: - Initialization
    public init(device: MTLDevice) {
        self.device = device
    }
    
    // MARK: - Public Interface
    
    /// Initialize the compute shader manager
    public func initialize() async throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw ComputeError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue
        
        try await setupComputeShaders()
        print("ComputeShaderManager initialized successfully")
    }
    
    /// Execute a compute shader by name
    public func dispatchShader(named name: String,
                               data: UnsafeMutableRawPointer?,
                               dataSize: Int,
                               threadsPerGrid: MTLSize,
                               threadsPerThreadgroup: MTLSize) throws {
        
        guard let pipelineState = computePipelineStates[name] else {
            throw ComputeError.shaderNotFound(name)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw ComputeError.commandBufferCreationFailed
        }
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw ComputeError.encoderCreationFailed
        }
        
        encoder.setComputePipelineState(pipelineState)
        
        // Set buffer data if provided
        if let data = data, dataSize > 0 {
            if let buffer = computeBuffers[name] {
                buffer.contents().copyMemory(from: data, byteCount: dataSize)
                encoder.setBuffer(buffer, offset: 0, index: 0)
            } else {
                let buffer = device.makeBuffer(bytes: data, length: dataSize, options: [])
                encoder.setBuffer(buffer, offset: 0, index: 0)
                computeBuffers[name] = buffer
            }
        }
        
        encoder.dispatchThreadgroups(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    /// Execute audio visualization compute shader
    public func visualizeAudio(audioData: [Float], outputTexture: MTLTexture) throws {
        let audioBuffer = device.makeBuffer(bytes: audioData,
                                           length: audioData.count * MemoryLayout<Float>.size,
                                           options: [])
        
        guard let pipelineState = computePipelineStates["audio_visualization"] else {
            throw ComputeError.shaderNotFound("audio_visualization")
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw ComputeError.commandBufferCreationFailed
        }
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw ComputeError.encoderCreationFailed
        }
        
        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(audioBuffer, offset: 0, index: 0)
        encoder.setTexture(outputTexture, index: 0)
        
        let threadsPerGrid = MTLSize(width: outputTexture.width,
                                     height: outputTexture.height,
                                     depth: 1)
        let threadsPerThreadgroup = MTLSize(width: 8, height: 8, depth: 1)
        
        encoder.dispatchThreadgroups(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    /// Execute particle system update
    public func updateParticles(particles: inout [Particle], deltaTime: Float) async throws {
        // Ensure particle pipeline is set up
        if computePipelineStates["particle_update"] == nil {
            try await setupParticlePipeline()
        }
        
        guard let particleBuffer = device.makeBuffer(bytes: &particles,
                                                     length: particles.count * MemoryLayout<Particle>.size,
                                                     options: []) else {
            throw ComputeError.commandBufferCreationFailed
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw ComputeError.commandBufferCreationFailed
        }
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw ComputeError.encoderCreationFailed
        }
        
        guard let pipelineState = computePipelineStates["particle_update"] else {
            throw ComputeError.shaderNotFound("particle_update")
        }
        
        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(particleBuffer, offset: 0, index: 0)
        
        var dt = deltaTime
        encoder.setBytes(&dt, length: MemoryLayout<Float>.size, index: 1)
        
        let threadsPerGrid = MTLSize(width: particles.count, height: 1, depth: 1)
        let threadsPerThreadgroup = MTLSize(width: min(256, particles.count), height: 1, depth: 1)
        
        encoder.dispatchThreadgroups(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        
        commandBuffer.commit()
        await commandBuffer.completed()
        
        // Copy results back to particles array
        let resultPointer = particleBuffer.contents().bindMemory(to: Particle.self, capacity: particles.count)
        for i in 0..<particles.count {
            particles[i] = resultPointer[i]
        }
    }
    
    // MARK: - Private Methods
    
    private func setupComputeShaders() async throws {
        // Load Metal library from framework bundle (same as MetalRenderingEngine)
        let frameworkBundle = Bundle(for: type(of: self))
        let library: MTLLibrary
        
        if let metalLibURL = frameworkBundle.url(forResource: "default", withExtension: "metallib") {
            library = try device.makeLibrary(URL: metalLibURL)
        } else if let defaultLibrary = device.makeDefaultLibrary() {
            library = defaultLibrary
        } else {
            throw ComputeError.libraryNotFound
        }
        
        // Setup compute shaders using Metal 4 descriptor-based API
        if let computeFunction = library.makeFunction(name: "compute_main") {
            let descriptor = MTLComputePipelineDescriptor()
            descriptor.computeFunction = computeFunction
            let result = try await device.makeComputePipelineState(descriptor: descriptor, options: [])
            computePipelineStates["compute_main"] = result.0
        }
        
        if let audioVisualizationFunction = library.makeFunction(name: "audio_visualization") {
            let descriptor = MTLComputePipelineDescriptor()
            descriptor.computeFunction = audioVisualizationFunction
            let result = try await device.makeComputePipelineState(descriptor: descriptor, options: [])
            computePipelineStates["audio_visualization"] = result.0
        }
    }
    
    private func setupParticlePipeline() async throws {
        // Load Metal library from framework bundle
        let frameworkBundle = Bundle(for: type(of: self))
        let library: MTLLibrary
        
        if let metalLibURL = frameworkBundle.url(forResource: "default", withExtension: "metallib") {
            library = try device.makeLibrary(URL: metalLibURL)
        } else if let defaultLibrary = device.makeDefaultLibrary() {
            library = defaultLibrary
        } else {
            throw ComputeError.libraryNotFound
        }
        
        // Create particle update pipeline state
        guard let particleFunction = library.makeFunction(name: "particle_update") else {
            throw ComputeError.shaderNotFound("particle_update")
        }
        
        let descriptor = MTLComputePipelineDescriptor()
        descriptor.computeFunction = particleFunction
        let result = try await device.makeComputePipelineState(descriptor: descriptor, options: [])
        computePipelineStates["particle_update"] = result.0
        
        print("Particle pipeline initialized successfully")
    }
}

// MARK: - Data Structures
public struct Particle: Sendable {
    public var position: SIMD3<Float>
    public var velocity: SIMD3<Float>
    public var color: SIMD4<Float>
    public var lifetime: Float
    
    public init(position: SIMD3<Float>, velocity: SIMD3<Float>, color: SIMD4<Float>, lifetime: Float) {
        self.position = position
        self.velocity = velocity
        self.color = color
        self.lifetime = lifetime
    }
}

// MARK: - Errors
public enum ComputeError: Error, Sendable {
    case commandQueueCreationFailed
    case commandBufferCreationFailed
    case encoderCreationFailed
    case libraryNotFound
    case shaderNotFound(String)
}

