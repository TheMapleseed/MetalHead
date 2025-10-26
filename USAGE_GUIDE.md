# MetalHead Usage Guide

Complete step-by-step guide to using the MetalHead multimedia engine.

---

## 🚀 Getting Started

### Prerequisites
- macOS 14.0 or later
- Xcode 15.0 or later
- Apple Silicon Mac (M1/M2/M3)

### Installation
```bash
git clone https://github.com/TheMapleseed/MetalHead.git
cd MetalHead
open MetalHead.xcodeproj
```

---

## 📖 Table of Contents
1. [Basic Setup](#basic-setup)
2. [3D Rendering](#3d-rendering)
3. [Audio Playback](#audio-playback)
4. [Input Handling](#input-handling)
5. [Performance Monitoring](#performance-monitoring)
6. [Memory Management](#memory-management)
7. [Advanced Features](#advanced-features)

---

## 🎯 Basic Setup

### Step 1: Initialize the Engine

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
                        try await engine.initialize()
                        try await engine.start()
                    }
                }
        }
    }
}
```

### Step 2: Access Subsystems

```swift
// In your view
@EnvironmentObject var engine: UnifiedMultimediaEngine

// Get any subsystem
if let rendering = engine.getSubsystem(MetalRenderingEngine.self) {
    // Use rendering
}

if let audio = engine.getSubsystem(AudioEngine.self) {
    // Use audio
}
```

---

## 🎨 3D Rendering

### Rendering a Basic Scene

```swift
// 1. Get rendering engine
guard let renderingEngine = engine.getSubsystem(MetalRenderingEngine.self) else {
    return
}

// 2. Enable 3D mode
renderingEngine.toggle3DMode()

// 3. Render (in MTKView delegate)
func draw(in view: MTKView) {
    let deltaTime = 1.0 / 120.0
    renderingEngine.render(deltaTime: deltaTime, in: view)
}
```

### Handling Mouse Input

```swift
// Update mouse position
renderingEngine.updateMousePosition(mousePosition)

// Handle mouse click
renderingEngine.handleMouseClick(at: clickPosition)

// Handle mouse scroll (for camera zoom)
renderingEngine.handleMouseScroll(delta: scrollDelta)
```

### Camera Control Example

```swift
// The rendering engine includes a camera system
// Mouse movement rotates camera
// Scroll zooms in/out

// Get camera properties
let camera = renderingEngine.camera // Access camera object

// Camera is automatically updated with mouse input
```

---

## 🎵 Audio Playback

### Basic Audio Setup

```swift
// 1. Get audio engine
guard let audioEngine = engine.getSubsystem(AudioEngine.self) else {
    return
}

// 2. Initialize (done automatically)
// audioEngine is ready to use

// 3. Load and play audio
try await audioEngine.loadAudioFile(url: audioFileURL)
audioEngine.play()
```

### Volume Control

```swift
// Set volume (0.0 to 1.0)
audioEngine.setVolume(0.8)

// Get current volume
let currentVolume = audioEngine.volume
```

### 3D Spatial Audio

```swift
// Position audio in 3D space
audioEngine.setSpatialPosition(SIMD3<Float>(x: 0, y: 0, z: -5))

// Sound will:
// - Attenuate based on distance
// - Pan based on direction
// - Follow 3D positioning rules
```

### Audio Effects

```swift
// Add reverb
audioEngine.applyReverb(intensity: 0.5) // 0.0 to 1.0

// Add delay
audioEngine.applyDelay(
    time: 0.5,       // Delay time in seconds
    feedback: 0.3,   // Feedback amount
    mix: 0.4         // Wet/dry mix
)
```

### Real-time Audio Processing

```swift
// Access audio data for visualization
let spectrum = audioEngine.getSpectrumData()
let level = audioEngine.getAudioLevel()

// Subscribe to audio updates
audioEngine.getAudioDataPublisher()
    .sink { audioData in
        // Process audio data
        visualizeAudio(audioData)
    }
```

---

## 🎮 Input Handling

### Basic Input Setup

```swift
// 1. Get input manager
guard let input = engine.getSubsystem(InputManager.self) else {
    return
}

// 2. Capture mouse (for first-person controls)
input.captureMouse()

// 3. Check key presses
if input.isKeyPressed(49) { // Space key
    // Jump action
}
```

### Key Mapping

```swift
// Set up custom key mappings
input.setKeyMapping("jump", to: 49)     // Space
input.setKeyMapping("run", to: 15)       // Shift
input.setKeyMapping("crouch", to: 6)    // Ctrl

// Use mapped keys
if input.isKeyPressed("jump") {
    player.jump()
}

if input.isKeyPressed("run") {
    player.run()
}
```

### Action Bindings

```swift
// Bind multiple keys to an action
input.setActionBinding("move", to: [13, 0, 1, 2]) // W, A, S, D

// Check action
if input.isActionPressed("move") {
    // Move player
}

// Get all bound keys
if let keys = input.getActionBinding("move") {
    for key in keys {
        // Process each key
    }
}
```

### Mouse Capture (First-Person Controls)

```swift
// Capture mouse for FPS controls
input.captureMouse()

// Access mouse deltas
let delta = input.mouseDelta
camera.rotate(delta)

// Release mouse to free cursor
input.releaseMouse()

// Toggle capture
input.toggleMouseCapture()
```

### Gamepad Support

```swift
// Setup gamepad discovery
input.setupGamepadSupport()

// Get connected gamepads
let gamepads = input.getConnectedGamepads()

// Access gamepad input
if let gamepad = gamepads.first,
   let gamepadInput = input.getGamepadInput(gamepad) {
    
    // Use gamepad input
    let leftStick = gamepadInput.leftStick      // 2D stick
    let buttonAPressed = gamepadInput.buttonA   // Bool
    
    player.move(leftStick)
    if buttonAPressed {
        player.jump()
    }
}

// Subscribe to gamepad events
input.gamepadPublisher.sink { event in
    // Handle gamepad events
    handleGamepadEvent(event)
}
```

### Input Sensitivity

```swift
// Adjust mouse sensitivity (0.1 to 10.0)
input.setMouseSensitivity(2.0)

// Adjust scroll sensitivity
input.setScrollSensitivity(1.5)

// Adjust general input sensitivity
input.setInputSensitivity(0.8)
```

---

## 📈 Performance Monitoring

### Basic Monitoring

```swift
// 1. Get performance monitor
guard let monitor = engine.getSubsystem(PerformanceMonitor.self) else {
    return
}

// 2. Start monitoring
monitor.startMonitoring()

// 3. Get performance metrics
let report = monitor.getPerformanceReport()
print("FPS: \(report.fps)")
print("Memory: \(report.formattedMemoryUsage)")
print("CPU: \(report.cpuUtilization * 100)%")
print("GPU: \(report.gpuUtilization * 100)%")
```

### Frame-by-Frame Monitoring

```swift
// In your render loop
let startTime = CACurrentMediaTime()

// Render frame...

let endTime = CACurrentMediaTime()
let frameTime = endTime - startTime

// Record frame time
monitor.recordFrameTime(frameTime)
```

### Performance Utilities

```swift
// Measure execution time
let (result, time) = PerformanceUtils.measureTime {
    expensiveOperation()
}
print("Execution time: \(time.formatted)")

// Benchmark a function
let benchmark = try PerformanceUtils.benchmark(iterations: 100) {
    functionToBenchmark()
}
print(benchmark.formatted)
```

---

## 💾 Memory Management

### Allocating Vertex Data

```swift
// 1. Get memory manager
guard let memory = engine.getSubsystem(MemoryManager.self) else {
    return
}

// 2. Allocate vertex buffer
let vertices = memory.allocateVertexData(count: 1000, type: Vertex.self)

// 3. Fill vertex data
for i in 0..<vertices.count {
    vertices[i] = Vertex(
        position: SIMD3<Float>(
            Float(i),
            Float(sin(Double(i))),
            Float(cos(Double(i)))
        ),
        color: SIMD4<Float>(1, 0, 0, 1)
    )
}

// 4. Deallocate when done
memory.deallocate(vertices)
```

### Allocating Uniform Data

```swift
// Allocate uniform buffer
let uniforms = memory.allocateUniformData(count: 100, type: Uniforms.self)

// Fill uniform data
uniforms[0] = Uniforms(
    modelMatrix: matrix_identity_float4x4,
    viewMatrix: viewMatrix,
    projectionMatrix: projectionMatrix,
    time: currentTime
)

// Deallocate
memory.deallocate(uniforms)
```

### Using Metal Buffers

```swift
// Get Metal buffer for direct use
let buffer = memory.getMetalBuffer(size: 1024, options: [])

// Use in Metal commands
commandEncoder.setVertexBuffer(buffer, offset: 0, index: 0)

// Return buffer when done
memory.returnMetalBuffer(buffer!)
```

### Memory Reports

```swift
// Get comprehensive memory report
let report = memory.getMemoryReport()

print("Total allocated: \(report.totalAllocated) bytes")
print("Active allocations: \(report.activeAllocations)")
print("Fragmentation: \(report.fragmentation)")

// Per-region reports
for (type, region) in report.regionReports {
    print("\(region.name): \(region.allocatedSize) bytes")
    print("Utilization: \(region.utilization * 100)%")
}
```

### Memory Compaction

```swift
// Compact memory to reduce fragmentation
memory.compactMemory()
```

---

## ⏱️ Clock System

### Basic Clock Usage

```swift
// 1. Get clock system
guard let clock = engine.getSubsystem(UnifiedClockSystem.self) else {
    return
}

// 2. Start clock
clock.start()

// 3. Access time
let currentTime = clock.getCurrentTime()
let frameNumber = clock.getCurrentFrame()
let fps = clock.getFrameRate()
```

### Compensated Time

```swift
// Get time compensated for rendering latency
let renderTime = clock.getCompensatedTime(for: .rendering)

// Use in rendering
updateRendering(time: renderTime)

// Get time for audio
let audioTime = clock.getCompensatedTime(for: .audio)
updateAudio(time: audioTime)
```

### Timing Callbacks

```swift
// Add callback for specific subsystem
clock.addTimingCallback(for: .rendering) { time, deltaTime in
    updateRendering(time: time, deltaTime: deltaTime)
}

clock.addTimingCallback(for: .audio) { time, deltaTime in
    updateAudio(time: time, deltaTime: deltaTime)
}

// Add global callback
clock.addGlobalTimingCallback { time, deltaTime in
    // All subsystems receive this timing
    updateGame(time: time, deltaTime: deltaTime)
}
```

### Performance Metrics

```swift
// Get timing metrics
let metrics = clock.getPerformanceMetrics()

print("Total frames: \(metrics.totalFrames)")
print("Average frame time: \(metrics.averageFrameTime)")
print("Frame time variance: \(metrics.frameTimeVariance)")
print("Max frame time: \(metrics.maxFrameTime)")
```

---

## 🎨 2D Graphics

### Sprite Rendering

```swift
// 1. Get graphics 2D
guard let graphics2D = engine.getSubsystem(Graphics2D.self) else {
    return
}

// 2. Load texture
let texture = try graphics2D.loadTexture(from: imageData, name: "player_sprite")

// 3. Draw sprite
graphics2D.drawSprite(
    at: SIMD2<Float>(100, 100),
    size: SIMD2<Float>(64, 64),
    texture: texture,
    color: SIMD4<Float>(1, 1, 1, 1)
)

// 4. Render (in main render loop)
graphics2D.render(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
```

### Drawing Shapes

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

### Text Rendering

```swift
// Draw text
graphics2D.drawText(
    "Score: 1000",
    at: SIMD2<Float>(10, 10),
    size: 24,
    color: SIMD4<Float>(1, 1, 1, 1)
)
```

---

## 🔧 Error Handling

### Handling Errors

```swift
// Add error callback
ErrorHandler.shared.addErrorCallback { error in
    print("Error: \(error.message)")
    
    switch error.severity {
    case .critical:
        // Handle critical errors
        handleCriticalError(error)
    case .error:
        // Handle errors
        handleError(error)
    case .warning:
        // Handle warnings
        handleWarning(error)
    case .info:
        // Handle info
        handleInfo(error)
    }
}
```

### Validation

```swift
// Validate device before use
if ErrorHandler.shared.validateDevice(device) {
    // Safe to use device
}

// Validate memory allocation
if ErrorHandler.shared.validateMemoryAllocation(size: size, alignment: alignment) {
    // Safe to allocate
}

// Validate frame rate
if ErrorHandler.shared.validateFrameRate(120.0) {
    // Valid frame rate
}
```

---

## 🎮 Complete Game Loop Example

```swift
func updateGame(deltaTime: TimeInterval) {
    // Get all subsystems
    guard let rendering = engine.getSubsystem(MetalRenderingEngine.self),
          let audio = engine.getSubsystem(AudioEngine.self),
          let input = engine.getSubsystem(InputManager.self),
          let clock = engine.getSubsystem(UnifiedClockSystem.self) else {
        return
    }
    
    // Update player input
    if input.isActionPressed("move_forward") {
        player.moveForward()
    }
    
    // Update camera from mouse
    let mouseDelta = input.mouseDelta
    camera.rotate(delta: mouseDelta)
    
    // Update 3D audio position
    audio.setSpatialPosition(player.position)
    
    // Get compensated time for rendering
    let renderTime = clock.getCompensatedTime(for: .rendering)
    
    // Render scene
    rendering.render(deltaTime: deltaTime, in: view)
    
    // Check performance
    if let monitor = engine.getSubsystem(PerformanceMonitor.self) {
        let report = monitor.getPerformanceReport()
        if report.fps < 60 {
            // Reduce quality for better performance
            adjustQualitySettings()
        }
    }
}
```

---

## 📚 Next Steps

- Read [API_REFERENCE.md](API_REFERENCE.md) for complete API documentation
- Check [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) for architecture details
- Review [BUILD_SYSTEM.md](BUILD_SYSTEM.md) for build and test information

---

**Happy Coding with MetalHead! 🚀**
