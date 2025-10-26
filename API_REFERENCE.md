# MetalHead API Reference

Complete guide to using the MetalHead multimedia engine APIs.

---

## 🚀 Quick Start

```swift
import MetalHead

// Initialize the engine
let engine = UnifiedMultimediaEngine()
try await engine.initialize()
try await engine.start()

// Access subsystems
if let renderingEngine = engine.getSubsystem(MetalRenderingEngine.self) {
    // Use rendering engine
}
```

---

## 📚 Core APIs

### UnifiedMultimediaEngine

Main orchestrator for all subsystems.

#### Initialization
```swift
let engine = UnifiedMultimediaEngine()
try await engine.initialize()
try await engine.start()
```

#### Subsystem Access
```swift
// Get any subsystem
if let rendering = engine.getSubsystem(MetalRenderingEngine.self) {
    // Use rendering engine
}

if let audio = engine.getSubsystem(AudioEngine.self) {
    // Use audio engine
}

if let input = engine.getSubsystem(InputManager.self) {
    // Use input manager
}

if let memory = engine.getSubsystem(MemoryManager.self) {
    // Use memory manager
}

if let clock = engine.getSubsystem(UnifiedClockSystem.self) {
    // Use clock system
}

if let performance = engine.getSubsystem(PerformanceMonitor.self) {
    // Use performance monitor
}
```

#### Lifecycle Management
```swift
// Start the engine
try await engine.start()

// Stop the engine
engine.stop()

// Pause the engine
engine.pause()

// Resume the engine
try await engine.resume()
```

#### Performance Metrics
```swift
// Get performance metrics
let metrics = engine.getPerformanceMetrics()
print("FPS: \(metrics.fps)")
print("Memory: \(metrics.formattedMemoryUsage)")
print("CPU: \(metrics.cpuUtilization * 100)%")
```

---

## 🎨 Rendering API

### MetalRenderingEngine

3D rendering with Metal 4 acceleration.

#### Properties
```swift
@Published var fps: Int                    // Current frames per second
@Published var is3DMode: Bool             // 3D rendering enabled
@Published var is2DMode: Bool             // 2D rendering enabled
public let device: MTLDevice               // Metal device
```

#### Initialization
```swift
let renderingEngine = MetalRenderingEngine(device: device)
try await renderingEngine.initialize()
```

#### Rendering
```swift
// Render a frame
renderingEngine.render(deltaTime: 1.0/120.0, in: mtkView)

// Update drawable size
renderingEngine.updateDrawableSize(CGSize(width: 1920, height: 1080))
```

#### Mode Control
```swift
// Toggle 3D mode
renderingEngine.toggle3DMode()

// Toggle 2D mode
renderingEngine.toggle2DMode()
```

#### Mouse Input
```swift
// Update mouse position
renderingEngine.updateMousePosition(SIMD2<Float>(100, 200))

// Handle mouse click
renderingEngine.handleMouseClick(at: SIMD2<Float>(150, 250))

// Handle mouse scroll
renderingEngine.handleMouseScroll(delta: SIMD2<Float>(0, 1))
```

---

## 🎵 Audio API

### AudioEngine

Real-time audio processing and spatial audio.

#### Properties
```swift
@Published var isPlaying: Bool            // Is audio playing
@Published var volume: Float               // Volume (0.0 - 1.0)
@Published var sampleRate: Double          // Sample rate
@Published var bufferSize: UInt32          // Buffer size
@Published var audioLevel: Float          // Current audio level
@Published var audioSpectrum: [Float]     // FFT spectrum data
```

#### Initialization
```swift
let audioEngine = AudioEngine()
try await audioEngine.initialize()
```

#### Playback Control
```swift
// Play audio
audioEngine.play()

// Stop audio
audioEngine.stop()

// Pause audio
audioEngine.pause()

// Resume audio
audioEngine.resume()
```

#### Volume Control
```swift
// Set volume
audioEngine.setVolume(0.8)

// Get current volume
let volume = audioEngine.volume
```

#### Spatial Audio
```swift
// Set 3D position
audioEngine.setSpatialPosition(SIMD3<Float>(x: 0, y: 0, z: -5))

// Sound will attenuate based on distance and direction
```

#### Audio Effects
```swift
// Apply reverb
audioEngine.applyReverb(intensity: 0.5)

// Apply delay
audioEngine.applyDelay(time: 0.5, feedback: 0.3, mix: 0.4)
```

#### Audio Loading
```swift
// Load from URL
try await audioEngine.loadAudioFile(url: fileURL)

// Load from data
try await audioEngine.loadAudioFile(data: audioData, name: "background_music")
```

#### Audio Data Access
```swift
// Get audio data publisher
let audioPublisher = audioEngine.getAudioDataPublisher()

// Get spectrum data
let spectrum = audioEngine.getSpectrumData()

// Get audio level
let level = audioEngine.getAudioLevel()
```

---

## 🎮 Input API

### InputManager

Multi-device input handling (keyboard, mouse, gamepad).

#### Properties
```swift
@Published var isMouseCaptured: Bool        // Mouse captured state
@Published var mousePosition: SIMD2<Float>  // Current mouse position
@Published var mouseDelta: SIMD2<Float>      // Mouse movement delta
@Published var scrollDelta: SIMD2<Float>     // Scroll wheel delta
```

#### Initialization
```swift
let inputManager = InputManager()
try await inputManager.initialize()
```

#### Mouse Control
```swift
// Capture mouse
inputManager.captureMouse()

// Release mouse
inputManager.releaseMouse()

// Toggle mouse capture
inputManager.toggleMouseCapture()
```

#### Sensitivity Control
```swift
// Set mouse sensitivity
inputManager.setMouseSensitivity(2.0)

// Set scroll sensitivity
inputManager.setScrollSensitivity(1.5)

// Set input sensitivity
inputManager.setInputSensitivity(0.8)
```

#### Key Mapping
```swift
// Set key mapping
inputManager.setKeyMapping("jump", to: 49) // Space key
inputManager.setKeyMapping("run", to: 15)  // Shift key

// Get key mapping
let keyCode = inputManager.getKeyMapping("jump")
```

#### Action Bindings
```swift
// Set action binding
inputManager.setActionBinding("move_forward", to: [13, 0]) // W and A

// Get action binding
let keys = inputManager.getActionBinding("move_forward")
```

#### Key State
```swift
// Check if key is pressed
if inputManager.isKeyPressed(49) { // Space
    // Jump action
}

// Check by name
if inputManager.isKeyPressed("jump") {
    // Jump action
}

// Check mouse button
if inputManager.isMouseButtonPressed(.left) {
    // Left mouse button
}

// Check action
if inputManager.isActionPressed("move_forward") {
    // Move forward
}
```

#### Input Publishers
```swift
// Subscribe to keyboard events
inputManager.keyboardPublisher.sink { keyCode in
    print("Key pressed: \(keyCode)")
}

// Subscribe to mouse events
inputManager.mousePublisher.sink { event in
    print("Mouse event: \(event.type)")
}

// Subscribe to gamepad events
inputManager.gamepadPublisher.sink { event in
    print("Gamepad event: \(event.element)")
}
```

#### Gamepad Support
```swift
// Setup gamepad support
inputManager.setupGamepadSupport()

// Get connected gamepads
let gamepads = inputManager.getConnectedGamepads()

// Get gamepad input
if let gamepad = gamepads.first {
    let input = inputManager.getGamepadInput(gamepad)
    let leftStick = input.leftStick
    let buttonPressed = input.buttonA
}

// Stop gamepad discovery
inputManager.stopGamepadDiscovery()
```

---

## 💾 Memory API

### MemoryManager

Dynamic memory allocation with proper alignment.

#### Initialization
```swift
let memoryManager = MemoryManager(device: metalDevice)
```

#### Vertex Data Allocation
```swift
// Allocate vertex data
let vertices = memoryManager.allocateVertexData(count: 1000, type: Vertex.self)

// Access data
for i in 0..<vertices.count {
    vertices[i] = Vertex(position: SIMD3<Float>(0, 0, 0), color: SIMD4<Float>(1, 0, 0, 1))
}

// Deallocate
memoryManager.deallocate(vertices)
```

#### Uniform Data Allocation
```swift
// Allocate uniform data
let uniforms = memoryManager.allocateUniformData(count: 100, type: Uniforms.self)

// Use uniform data
uniforms[0] = Uniforms(
    modelMatrix: matrix_identity_float4x4,
    viewMatrix: matrix_identity_float4x4,
    projectionMatrix: matrix_identity_float4x4,
    time: 0.0
)

// Deallocate
memoryManager.deallocate(uniforms)
```

#### Audio Data Allocation
```swift
// Allocate audio buffer
let audioBuffer = memoryManager.allocateAudioData(count: 1024)

// Fill audio data
for i in 0..<audioBuffer.count {
    audioBuffer[i] = Float.random(in: -1...1)
}

// Deallocate
memoryManager.deallocate(audioBuffer)
```

#### Texture Data Allocation
```swift
// Allocate texture data
let textureData = memoryManager.allocateTextureData(width: 512, height: 512, bytesPerPixel: 4)

// Fill texture data
for i in 0..<textureData.count {
    textureData[i] = UInt8(i % 256)
}

// Deallocate
memoryManager.deallocate(textureData)
```

#### Metal Buffer Integration
```swift
// Get Metal buffer
let buffer = memoryManager.getMetalBuffer(size: 1024, options: [])

// Use buffer in Metal commands
commandEncoder.setVertexBuffer(buffer, offset: 0, index: 0)

// Return buffer
memoryManager.returnMetalBuffer(buffer!)
```

#### Memory Reports
```swift
// Get memory report
let report = memoryManager.getMemoryReport()
print("Total allocated: \(report.totalAllocated)")
print("Active allocations: \(report.activeAllocations)")
print("Fragmentation: \(report.fragmentation)")

// For each region
for (type, region) in report.regionReports {
    print("\(region.name): \(region.allocatedSize) bytes")
}
```

#### Memory Compaction
```swift
// Compact memory to reduce fragmentation
memoryManager.compactMemory()
```

---

## ⏱️ Clock API

### UnifiedClockSystem

Master clock for perfect synchronization.

#### Initialization
```swift
let clockSystem = UnifiedClockSystem()
clockSystem.start()
```

#### Time Access
```swift
// Get current master time
let currentTime = clockSystem.getCurrentTime()

// Get current frame number
let frameNumber = clockSystem.getCurrentFrame()

// Get frame rate
let fps = clockSystem.getFrameRate()

// Set target frame rate
clockSystem.setTargetFrameRate(120.0)
```

#### Compensated Time
```swift
// Get compensated time for rendering
let renderTime = clockSystem.getCompensatedTime(for: .rendering)

// Get compensated time for audio
let audioTime = clockSystem.getCompensatedTime(for: .audio)

// Get compensated time for input
let inputTime = clockSystem.getCompensatedTime(for: .input)

// Get compensated time for physics
let physicsTime = clockSystem.getCompensatedTime(for: .physics)
```

#### Timing Callbacks
```swift
// Add timing callback for specific subsystem
clockSystem.addTimingCallback(for: .rendering) { time, deltaTime in
    // Update rendering with synchronized timing
    updateRendering(time: time, deltaTime: deltaTime)
}

// Add global timing callback
clockSystem.addGlobalTimingCallback { time, deltaTime in
    // Update all subsystems with synchronized timing
    updateAllSubsystems(time: time, deltaTime: deltaTime)
}
```

#### Performance Metrics
```swift
// Get performance metrics
let metrics = clockSystem.getPerformanceMetrics()
print("Total frames: \(metrics.totalFrames)")
print("Average frame time: \(metrics.averageFrameTime)")
print("Frame time variance: \(metrics.frameTimeVariance)")
print("Max frame time: \(metrics.maxFrameTime)")
print("Timing drift: \(metrics.timingDrift)")
```

---

## 📈 Performance API

### PerformanceMonitor

Real-time performance monitoring and optimization.

#### Initialization
```swift
let monitor = PerformanceMonitor(device: metalDevice)
monitor.startMonitoring()
```

#### Metrics Access
```swift
// Get performance report
let report = monitor.getPerformanceReport()
print("FPS: \(report.fps)")
print("Frame time: \(report.frameTime)")
print("Memory usage: \(report.formattedMemoryUsage)")
print("GPU utilization: \(report.gpuUtilization)")
print("CPU utilization: \(report.cpuUtilization)")

// Access detailed metrics
print("Average frame time: \(report.averageFrameTime)")
print("Min frame time: \(report.minFrameTime)")
print("Max frame time: \(report.maxFrameTime)")
print("Frame time variance: \(report.frameTimeVariance)")
```

#### Frame Time Recording
```swift
// Record frame time for each frame
monitor.recordFrameTime(deltaTime)
```

#### Utility Functions
```swift
// Measure execution time
let (result, time) = PerformanceUtils.measureTime {
    // Operation to measure
    someExpensiveOperation()
}
print("Execution time: \(time.formatted)")

// Benchmark a function
let benchmark = try PerformanceUtils.benchmark(iterations: 100) {
    functionToBenchmark()
}
print(benchmark.formatted)
```

---

## 🎨 2D Graphics API

### Graphics2D

2D sprite and shape rendering.

#### Initialization
```swift
let graphics2D = Graphics2D(device: metalDevice)
try await graphics2D.initialize()
```

#### Sprite Rendering
```swift
// Draw sprite
graphics2D.drawSprite(
    at: SIMD2<Float>(100, 100),
    size: SIMD2<Float>(200, 200),
    texture: spriteTexture,
    color: SIMD4<Float>(1, 1, 1, 1)
)
```

#### Shape Drawing
```swift
// Draw rectangle
graphics2D.drawRectangle(
    at: SIMD2<Float>(50, 50),
    size: SIMD2<Float>(100, 100),
    color: SIMD4<Float>(1, 0, 0, 1)
)

// Draw circle
graphics2D.drawCircle(
    at: SIMD2<Float>(200, 200),
    radius: 50,
    color: SIMD4<Float>(0, 1, 0, 1)
)

// Draw line
graphics2D.drawLine(
    from: SIMD2<Float>(0, 0),
    to: SIMD2<Float>(100, 100),
    thickness: 2,
    color: SIMD4<Float>(0, 0, 1, 1)
)
```

#### Text Rendering
```swift
// Draw text
graphics2D.drawText(
    "Hello, MetalHead!",
    at: SIMD2<Float>(10, 10),
    size: 24,
    color: SIMD4<Float>(1, 1, 1, 1)
)
```

#### Texture Loading
```swift
// Load texture from image data
let texture = try graphics2D.loadTexture(from: imageData, name: "sprite")
```

#### Color Control
```swift
// Set current color
graphics2D.setColor(SIMD4<Float>(1, 0.5, 0, 1))
```

#### Rendering
```swift
// Render 2D graphics (called from main render loop)
graphics2D.render(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
```

#### Clearing
```swift
// Clear all drawable elements
graphics2D.clear()
```

---

## 🛠️ Error Handling API

### ErrorHandler

Comprehensive error handling and validation.

#### Error Handling
```swift
// Handle error
ErrorHandler.shared.handleError(EngineError(
    type: .renderingError,
    message: "Failed to create render pipeline",
    severity: .error
))

// Handle warning
ErrorHandler.shared.handleWarning(EngineWarning(
    type: .performance,
    message: "Frame rate dropped below 60 FPS"
))

// Add error callback
ErrorHandler.shared.addErrorCallback { error in
    print("Error occurred: \(error.message)")
}
```

#### Validation
```swift
// Validate device
if ErrorHandler.shared.validateDevice(device) {
    // Device is valid
}

// Validate memory allocation
if ErrorHandler.shared.validateMemoryAllocation(size: 1024, alignment: 16) {
    // Memory allocation is valid
}

// Validate frame rate
if ErrorHandler.shared.validateFrameRate(120.0) {
    // Frame rate is valid
}

// Validate position
if ErrorHandler.shared.validatePosition(SIMD3<Float>(0, 0, 0)) {
    // Position is valid
}

// Validate color
if ErrorHandler.shared.validateColor(SIMD4<Float>(1, 0, 0, 1)) {
    // Color is valid
}
```

---

## 📊 Data Structures

### Vertices
```swift
struct Vertex {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
}
```

### Uniforms
```swift
struct Uniforms {
    var modelMatrix: matrix_float4x4
    var viewMatrix: matrix_float4x4
    var projectionMatrix: matrix_float4x4
    var time: Float
}
```

### Mouse Event
```swift
struct MouseEvent {
    let type: MouseEventType
    let position: SIMD2<Float>
    let button: MouseButton
    let clickCount: Int
    let scrollDelta: SIMD2<Float>
}

enum MouseEventType {
    case move, click, release, scroll
}

enum MouseButton {
    case left, right, middle, none
}
```

### Gamepad Input
```swift
struct GamepadInput {
    let leftStick: SIMD2<Float>
    let rightStick: SIMD2<Float>
    let leftTrigger: Float
    let rightTrigger: Float
    let buttonA: Bool
    let buttonB: Bool
    let buttonX: Bool
    let buttonY: Bool
    let leftShoulder: Bool
    let rightShoulder: Bool
    let dpad: SIMD2<Float>
}
```

---

## 🎯 Complete Example

```swift
import MetalHead

@main
struct MyApp: App {
    @StateObject private var engine = UnifiedMultimediaEngine()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .onAppear {
                    Task {
                        try await initializeEngine()
                    }
                }
        }
    }
    
    private func initializeEngine() async throws {
        // Initialize engine
        try await engine.initialize()
        try await engine.start()
        
        // Access subsystems
        if let rendering = engine.getSubsystem(MetalRenderingEngine.self) {
            rendering.toggle3DMode()
        }
        
        if let audio = engine.getSubsystem(AudioEngine.self) {
            audio.play()
            audio.setVolume(0.8)
        }
        
        if let input = engine.getSubsystem(InputManager.self) {
            input.captureMouse()
            input.setKeyMapping("jump", to: 49)
        }
        
        if let memory = engine.getSubsystem(MemoryManager.self) {
            let vertices = memory.allocateVertexData(count: 1000, type: Vertex.self)
            // Use vertices...
            memory.deallocate(vertices)
        }
        
        if let clock = engine.getSubsystem(UnifiedClockSystem.self) {
            clock.setTargetFrameRate(120.0)
            clock.addGlobalTimingCallback { time, deltaTime in
                // Update game logic
            }
        }
        
        if let performance = engine.getSubsystem(PerformanceMonitor.self) {
            performance.startMonitoring()
        }
    }
}
```

---

## 📚 Additional Resources

- [README.md](README.md) - Project overview
- [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) - Architecture details
- [BUILD_SYSTEM.md](BUILD_SYSTEM.md) - Build and test system
- [MEMORY_MANAGEMENT.md](MEMORY_MANAGEMENT.md) - Memory system details
- [UNIFIED_PIPELINE.md](UNIFIED_PIPELINE.md) - Pipeline system details

---

**MetalHead API** - Complete multimedia engine for macOS
