# API Guidelines

This document outlines the API design principles and usage guidelines for the MetalHead multimedia engine.

## Core Principles

### 1. Actor Isolation

All engine subsystems that require main actor isolation are annotated with `@MainActor`:

```swift
@MainActor
public class AudioEngine: ObservableObject {
    // ...
}
```

**Guidelines:**
- Access all `@MainActor` classes from the main thread
- Use `Task { @MainActor in ... }` to call from background contexts
- Never capture main actor types in non-isolated closures

### 2. Async/Await Concurrency

Use Swift 6 structured concurrency for all asynchronous operations:

```swift
public func start() async throws {
    // Initialization
}
```

**Guidelines:**
- Use `async/await` for all I/O and initialization
- Mark throwing functions with `throws`
- Use `try await` for operations that can throw and are async
- Implement proper error handling at call sites

### 3. Subsystem Access

Use the unified engine's type-safe subsystem getter:

```swift
let renderingEngine = engine.getSubsystem(MetalRenderingEngine.self)
let audioEngine = engine.getSubsystem(AudioEngine.self)
```

**Guidelines:**
- Always use optional unwrapping (`?`)
- Check for `nil` before using subsystems
- Store subsystem references if needed frequently

### 4. Memory Management

The engine uses custom memory management with precise alignment:

```swift
// Allocate with alignment
let buffer = memoryManager.allocate(
    size: 1024,
    alignment: 16,
    type: .vertex
)

// Return when done
memoryManager.deallocate(buffer)
```

**Guidelines:**
- Always deallocate memory when done
- Use appropriate alignment for buffer types:
  - `16 bytes`: SIMD vectors
  - `256 bytes`: Uniform buffers
  - `4 bytes`: Float arrays
  - `64 bytes`: Textures
- Check allocation success (returns nil on failure)

### 5. Error Handling

Use the comprehensive error handler for all operations:

```swift
ErrorHandler.handleError(.deviceFailure, severity: .critical) {
    // Recovery logic
}
```

**Error Types:**
- `.deviceFailure`: GPU or audio device issues
- `.memoryFailure`: Allocation failures
- `.initializationFailure`: Startup errors
- `.runtimeFailure`: Runtime exceptions
- `.synchronizationFailure`: Clock drift or timing issues

**Severity Levels:**
- `.critical`: System cannot continue
- `.error`: Function fails but system continues
- `.warning`: Degraded performance
- `.info`: Informational

### 6. Performance Monitoring

Track performance metrics throughout the engine lifecycle:

```swift
let monitor = PerformanceMonitor()
monitor.startMonitoring()

// Later
print("FPS: \(monitor.fps)")
print("Memory: \(monitor.memoryUsage) MB")
```

**Guidelines:**
- Monitor frame rate consistently (target 60 FPS)
- Track memory usage to prevent leaks
- Monitor CPU and GPU utilization
- Log performance warnings when thresholds are exceeded

## API Categories

### Rendering APIs

#### MetalRenderingEngine

```swift
// Initialize (called automatically by UnifiedMultimediaEngine)
public init(device: MTLDevice)

// Render a frame
public func render(deltaTime: TimeInterval, in view: MTKView)

// Render geometries
public func renderCube(at position: SIMD3<Float>)
public func renderSphere(at position: SIMD3<Float>, radius: Float)
```

#### Graphics2D

```swift
// Draw 2D shapes
public func drawRect(_ rect: CGRect, color: SIMD4<Float>)
public func drawCircle(_ center: CGPoint, radius: Float, color: SIMD4<Float>)
public func drawLine(from: CGPoint, to: CGPoint, color: SIMD4<Float>)
```

### Audio APIs

#### AudioEngine

```swift
// Control playback
public func play()
public func stop()
public func pause()
public func resume()

// Volume control
public func setVolume(_ volume: Float)
public func getAudioLevel() -> Float

// Spatial audio
public func setSpatialPosition(_ position: SIMD3<Float>)

// Load audio files
public func loadAudioFile(url: URL) async throws

// Get audio data
public func getSpectrumData() -> [Float]
```

**Note:** Audio operations run on the main actor.

### Input APIs

#### InputManager

```swift
// Keyboard events
public var keyboardEvents: AnyPublisher<KeyboardEvent, Never>

// Mouse events
public var mouseEvents: AnyPublisher<MouseEvent, Never>

// Gamepad support
public var gamepadConnected: AnyPublisher<GCController, Never>
public var gamepadDisconnected: AnyPublisher<GCController, Never>
```

**Event Types:**
- `KeyboardEvent`: Key press/release with key codes
- `MouseEvent`: Click/move with position
- `GamepadEvent`: Button/thumbstick input

### Memory APIs

#### MemoryManager

```swift
// Allocate memory
public func allocate(
    size: Int,
    alignment: Int,
    type: MemoryType
) -> UnsafeMutableRawPointer?

// Deallocate memory
public func deallocate(_ pointer: UnsafeMutableRawPointer)

// Get metrics
public func getMemoryReport() -> MemoryReport
```

**Memory Types:**
- `.vertex`: Vertex buffer data
- `.uniform`: Uniform buffer data
- `.audio`: Audio buffer data
- `.texture`: Texture data

### Timing APIs

#### UnifiedClockSystem

```swift
// Register timing callback
public func registerCallback(
    for subsystem: SubsystemType,
    callback: @escaping (TimeInterval) -> Void
)

// Get master time
public var masterTime: TimeInterval { get }

// Get system latency
public var systemLatency: TimeInterval { get }
```

### Advanced Rendering APIs

#### ComputeShaderManager

```swift
// GPU compute shaders for parallel processing
public let computeShaderManager: ComputeShaderManager

// Execute compute shader
try computeShaderManager.dispatchShader(
    named: "audio_visualization",
    data: audioData,
    dataSize: size,
    threadsPerGrid: gridSize,
    threadsPerThreadgroup: threadgroupSize
)

// Audio visualization
try computeShaderManager.visualizeAudio(
    audioData: frequencies,
    outputTexture: texture
)

// Particle system updates on GPU
try computeShaderManager.updateParticles(&particles, deltaTime: deltaTime)
```

#### OffscreenRenderer

```swift
// Render-to-texture for post-processing
public let offscreenRenderer: OffscreenRenderer

// Create render target
let texture = try offscreenRenderer.createRenderTarget(
    name: "postProcess",
    width: 1920,
    height: 1080
)

// Render to texture
try offscreenRenderer.renderToTexture(name: "postProcess") { encoder in
    // Encoding commands
}

// Blit textures
try offscreenRenderer.blitTexture(source: srcTexture, destination: dstTexture)
```

#### DeferredRenderer

```swift
// Deferred lighting pipeline
public let deferredRenderer: DeferredRenderer

// Initialize with render size
try deferredRenderer.initialize(width: 1920, height: 1080)

// Render G-Buffer pass
try deferredRenderer.renderGBuffer(
    commandBuffer: buffer,
    cameraViewMatrix: viewMatrix,
    geometries: meshes
)

// Render lighting pass
try deferredRenderer.renderLighting(commandBuffer: buffer, lights: lightArray)
```

#### TextureManager

```swift
// Intelligent texture caching
public let textureManager: TextureManager

// Load texture with caching
let texture = try textureManager.loadTexture(
    from: imageURL,
    generateMipmaps: true
)

// Get cached texture
let cached = textureManager.getTexture(key: "myTexture")

// Release texture
textureManager.releaseTexture(key: "myTexture")

// Get cache statistics
let stats = textureManager.getCacheStats()
```

### Testing APIs

#### TestAPI

```swift
// Run a complete health check
public func runHealthCheck(engine: UnifiedMultimediaEngine) async -> [TestReport]

// Start continuous monitoring
public func startMonitoring(engine: UnifiedMultimediaEngine, interval: TimeInterval = 5.0)

// Verify all subsystems
public func verifySubsystems() -> Bool
```

**Test Results:**
- `.passed`: Test completed successfully
- `.failed`: Test failed with error
- `.skipped`: Test was skipped
- `.warning`: Test passed with warnings

**Test Report Fields:**
- `subsystem`: Which subsystem was tested
- `testName`: Name of the test
- `result`: Test result status
- `duration`: How long the test took
- `message`: Additional information

### Monitoring APIs

#### PerformanceMonitor

```swift
// Start/stop monitoring
public func startMonitoring()
public func stopMonitoring()

// Read metrics
public var fps: Double { get }
public var memoryUsage: Int { get }
public var cpuUtilization: Double { get }
public var gpuUtilization: Double { get }
```

### Parallel Rendering

MetalHead utilizes **ALL CPU AND GPU CORES** for maximum performance:

#### CPU Core Utilization
- **Automatic CPU core detection** using `ProcessInfo.processInfo.processorCount`
- **Parallel rendering** with MTLParallelRenderCommandEncoder
- **Up to 8 concurrent threads** for optimal performance
- **Concurrent command encoding** across all available cores

#### GPU Core Utilization  
- **Multiple command queues** (3 queues for parallel GPU processing)
- **Automatic GPU work distribution** across all compute units
- **Compute shaders** utilize all available GPU cores
- **Metal automatically schedules** work across all GPU cores

**Usage:**
```swift
// Parallel rendering is automatic when using render3DParallel
// The engine detects CPU cores and distributes work accordingly

// CPU cores are used for parallel command encoding
// GPU cores are used for parallel command execution
// Metal handles GPU core distribution automatically
```

## Best Practices

### 1. Always Check for Subsystem Availability

```swift
guard let renderingEngine = engine.getSubsystem(MetalRenderingEngine.self) else {
    print("Rendering engine not available")
    return
}
```

### 2. Handle Errors Appropriately

```swift
do {
    try await engine.start()
} catch {
    ErrorHandler.handleError(.initializationFailure, severity: .critical)
    // Recovery logic
}
```

### 3. Use Structured Concurrency

```swift
Task { @MainActor [weak self] in
    guard let self = self else { return }
    await self.audioEngine?.play()
}
```

### 4. Monitor Performance

```swift
if monitor.fps < 30 {
    ErrorHandler.handleWarning(.lowFrameRate, severity: .warning)
}
```

### 5. Deallocate Resources

```swift
defer {
    memoryManager.deallocate(buffer)
}
```

## Thread Safety

- **Main Actor**: All rendering, audio, and input operations
- **Background Threads**: Memory allocation, FFT processing
- **Synchronization**: Use `NSLock` for shared mutable state

## Performance Targets

- **Frame Rate**: 60 FPS minimum
- **Memory Usage**: Monitor for leaks (static allocation expected)
- **CPU Usage**: < 20% per core
- **GPU Usage**: Monitor for bottlenecks
- **Audio Latency**: < 10ms total system latency

## Error Recovery

All subsystems implement automatic error recovery:

1. **Device Errors**: Attempt to reinitialize hardware
2. **Memory Errors**: Trigger garbage collection
3. **Synchronization Errors**: Adjust clock drift
4. **Initialization Errors**: Fallback to default configurations

## Logging

Use the category-based logging system:

```swift
Logger.shared.log(message: "Engine started", category: .system, level: .info)
Logger.shared.log(message: "Allocation failed", category: .memory, level: .error)
```

**Categories:**
- `.system`: General engine operations
- `.rendering`: Graphics operations
- `.audio`: Audio processing
- `.input`: Input handling
- `.memory`: Memory management
- `.performance`: Performance metrics

**Levels:**
- `.debug`: Debug information
- `.info`: Informational messages
- `.warning`: Warnings
- `.error`: Errors
- `.critical`: Critical failures

