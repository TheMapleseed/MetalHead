# Unified Pipeline System Documentation

## Overview

The MetalHead engine implements a comprehensive unified pipeline system that provides synchronized communication between all multimedia subsystems with a single master clock and advanced latency adjustment. This system ensures perfect timing coordination across 3D rendering, 2D graphics, audio processing, and input handling.

## Architecture

### Core Components

1. **UnifiedClockSystem**: Master clock with system time synchronization
2. **UnifiedPipeline**: Communication pipeline with message routing
3. **LatencyAdjustmentLibrary**: Advanced latency compensation system
4. **UnifiedMultimediaEngine**: Main orchestrator for all subsystems

### System Flow

```
┌─────────────────────────────────────────────────────────────┐
│                Unified Multimedia Engine                    │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │  Master Clock   │  │  Pipeline       │  │  Latency    │  │
│  │  System         │  │  Communication  │  │  Library    │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────┐ │
│  │  3D Render  │  │  2D Graphics│  │   Audio     │  │Input│ │
│  │   Engine    │  │   System    │  │   Engine    │  │Mgr  │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Unified Clock System

### Master Clock Features

- **Single Source of Truth**: One master clock synchronizes all subsystems
- **System Time Sync**: Integrates with macOS `timed` service
- **Latency Compensation**: Automatic adjustment for processing delays
- **Drift Correction**: Maintains timing accuracy over long periods
- **Audio Interruption Handling**: Responds to system audio changes

### Clock Synchronization

```swift
// Initialize unified clock system
let clockSystem = UnifiedClockSystem()

// Start master clock
clockSystem.start()

// Get synchronized time for any subsystem
let renderTime = clockSystem.getCompensatedTime(for: .rendering)
let audioTime = clockSystem.getCompensatedTime(for: .audio)
let inputTime = clockSystem.getCompensatedTime(for: .input)
```

### Timing Callbacks

```swift
// Add timing callbacks for subsystems
clockSystem.addTimingCallback(for: .rendering) { time, deltaTime in
    // Update rendering with synchronized timing
}

clockSystem.addGlobalTimingCallback { time, deltaTime in
    // Global timing updates
}
```

## Unified Pipeline Communication

### Message System

The pipeline provides a robust message routing system with priority queuing:

```swift
// Send message to specific subsystem
pipeline.sendMessage(
    to: .rendering,
    type: .render,
    data: renderData,
    priority: .high
)

// Broadcast message to all subsystems
pipeline.broadcastMessage(
    type: .synchronization,
    data: syncData,
    priority: .normal
)
```

### Event System

```swift
// Subscribe to events
pipeline.subscribe(to: .frameStart) { event in
    // Handle frame start
}

pipeline.subscribe(to: .audioStart) { event in
    // Handle audio start
}

// Publish events
pipeline.publishEvent(PipelineEvent(
    type: .frameEnd,
    source: .rendering,
    data: frameData
))
```

### Data Flow Management

```swift
// Register data flow
let vertexFlow = DataFlow<Vertex>(
    id: "vertex_data",
    source: .input,
    destination: .rendering
)
pipeline.registerDataFlow(vertexFlow)

// Send data through flow
pipeline.sendData(vertices, through: vertexFlow)
```

## Latency Adjustment Library

### Automatic Latency Measurement

The library continuously measures and compensates for latency:

```swift
// Measure latency for any operation
latencyLibrary.measureLatency(for: .rendering) {
    // Rendering operation
}

// Get current latency
let renderLatency = latencyLibrary.getCurrentLatency(for: .rendering)
```

### Compensation Strategies

Different subsystems use different compensation strategies:

- **Immediate**: No compensation (input)
- **Reactive**: Compensate based on recent measurements
- **Predictive**: Use trend analysis for future compensation
- **Adaptive**: Machine learning-based compensation

```swift
// Set compensation strategy
latencyLibrary.setCompensationStrategy(
    for: .rendering,
    strategy: .predictive
)
```

### Calibration

```swift
// Calibrate all subsystems
latencyLibrary.calibrate()

// Get performance metrics
let metrics = latencyLibrary.getPerformanceMetrics()
print("System latency: \(metrics.averageLatency)ms")
```

## Unified Multimedia Engine

### Single Entry Point

The unified engine provides a single interface for all multimedia operations:

```swift
// Initialize unified engine
let engine = UnifiedMultimediaEngine()
try await engine.initialize()
engine.start()

// Access subsystems
if let metalEngine = engine.getSubsystem(MetalEngine.self) {
    metalEngine.toggle3DMode()
}

if let audioEngine = engine.getSubsystem(AudioEngine.self) {
    audioEngine.play()
}
```

### Synchronized Operations

All operations are automatically synchronized:

```swift
// Send synchronized message
engine.sendMessage(
    to: .rendering,
    type: .render,
    data: renderData
)

// Broadcast synchronized event
engine.broadcastMessage(
    type: .synchronization,
    data: syncData
)
```

### Performance Monitoring

```swift
// Get unified performance metrics
let metrics = engine.getPerformanceMetrics()
print("Frame rate: \(metrics.frameRate)")
print("System latency: \(metrics.systemLatency)ms")
print("Sync quality: \(metrics.synchronizationQuality)%")
```

## Message Types

### Core Message Types

- **render**: 3D rendering commands
- **audio**: Audio processing data
- **input**: Input events and data
- **physics**: Physics simulation data
- **synchronization**: Timing and sync data
- **data**: General data transfer
- **event**: System events
- **command**: Control commands

### Message Priorities

- **high**: Critical timing-sensitive messages
- **normal**: Standard messages
- **low**: Background processing messages

## Event Types

### System Events

- **frameStart**: Frame rendering begins
- **frameEnd**: Frame rendering complete
- **audioStart**: Audio playback begins
- **audioEnd**: Audio playback ends
- **inputReceived**: Input event received
- **physicsUpdate**: Physics simulation update
- **synchronization**: Timing synchronization
- **error**: Error conditions

## Data Flow Patterns

### Vertex Data Flow

```swift
// Input → Processing → Rendering
let vertexFlow = DataFlow<Vertex>(
    id: "vertex_pipeline",
    source: .input,
    destination: .rendering,
    transform: { vertex in
        // Transform vertex data
        return transformedVertex
    }
)
```

### Audio Data Flow

```swift
// Audio Input → Processing → Output
let audioFlow = DataFlow<Float>(
    id: "audio_pipeline",
    source: .audio,
    destination: .audio,
    transform: { sample in
        // Apply audio effects
        return processedSample
    }
)
```

## Synchronization Patterns

### Frame Synchronization

```swift
// All subsystems synchronized to frame timing
engine.addSynchronizationCallback { time, deltaTime in
    // All subsystems receive same timing
    updateRendering(time: time, deltaTime: deltaTime)
    updateAudio(time: time, deltaTime: deltaTime)
    updateInput(time: time, deltaTime: deltaTime)
}
```

### Subsystem Synchronization

```swift
// Subsystem-specific timing
clockSystem.addTimingCallback(for: .rendering) { time, deltaTime in
    // Rendering-specific timing
    updateRendering(time: time, deltaTime: deltaTime)
}
```

## Performance Optimization

### Message Batching

```swift
// Batch multiple messages for efficiency
let messages = [
    PipelineMessage(type: .render, data: renderData1),
    PipelineMessage(type: .render, data: renderData2),
    PipelineMessage(type: .render, data: renderData3)
]
messages.forEach { pipeline.sendMessage($0) }
```

### Priority Queuing

```swift
// High priority for critical operations
pipeline.sendMessage(
    to: .rendering,
    type: .render,
    data: criticalRenderData,
    priority: .high
)
```

### Memory Management

```swift
// Use dynamic arrays for efficient memory management
let vertexArray = DynamicArrayManager.createVertexArray(device: device)
vertexArray.append(contentsOf: vertices)

// Get Metal buffer for rendering
if let metalBuffer = vertexArray.getMetalBuffer() {
    renderEncoder.setVertexBuffer(metalBuffer, offset: 0, index: 0)
}
```

## Error Handling

### Pipeline Errors

```swift
enum PipelineError: Error {
    case subsystemUnavailable
    case messageHandlingFailed
    case requestNotSupported
    case dataFlowError
}
```

### Synchronization Errors

```swift
// Handle timing drift
if timingDrift > maxDriftThreshold {
    clockSystem.correctTimingDrift()
}
```

### Latency Errors

```swift
// Handle excessive latency
if systemLatency > maxLatencyThreshold {
    latencyLibrary.recalibrate()
}
```

## Thread Safety

### Concurrent Access

- **Read Operations**: Lock-free concurrent access
- **Write Operations**: Serialized through message queue
- **Memory Management**: Thread-safe with proper locking
- **Clock Updates**: Atomic operations for timing

### Message Processing

```swift
// Thread-safe message processing
pipelineQueue.async {
    self.processMessages()
}
```

## Integration Examples

### 3D Rendering Integration

```swift
// Setup rendering with unified timing
engine.addSynchronizationCallback { time, deltaTime in
    if let metalEngine = engine.getSubsystem(MetalEngine.self) {
        metalEngine.updateTiming(time: time, deltaTime: deltaTime)
    }
}
```

### Audio Integration

```swift
// Setup audio with latency compensation
if let audioEngine = engine.getSubsystem(AudioEngine.self) {
    audioEngine.setLatencyCompensation(
        engine.getLatencyLibrary().getCurrentLatency(for: .audio)
    )
}
```

### Input Integration

```swift
// Setup input with synchronized timing
if let inputManager = engine.getSubsystem(InputManager.self) {
    inputManager.setClockSystem(engine.getClockSystem())
}
```

## Best Practices

### 1. Use Unified Engine

```swift
// Always use unified engine for subsystem access
let engine = UnifiedMultimediaEngine()
// Don't create subsystems directly
```

### 2. Leverage Synchronization

```swift
// Use synchronization callbacks for timing
engine.addSynchronizationCallback { time, deltaTime in
    // All subsystems receive synchronized timing
}
```

### 3. Monitor Performance

```swift
// Regular performance monitoring
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    let metrics = engine.getPerformanceMetrics()
    // Monitor and adjust based on metrics
}
```

### 4. Handle Latency

```swift
// Use latency compensation
let compensatedTime = engine.getLatencyLibrary().getCompensatedTime(for: .rendering)
```

### 5. Use Message System

```swift
// Use pipeline for subsystem communication
engine.sendMessage(to: .rendering, type: .render, data: renderData)
```

## Conclusion

The unified pipeline system provides:

- **Perfect Synchronization**: All subsystems operate with precise timing
- **Efficient Communication**: High-performance message routing
- **Automatic Latency Compensation**: Self-adjusting timing system
- **Thread Safety**: Concurrent access with proper synchronization
- **Performance Monitoring**: Real-time metrics and optimization
- **Easy Integration**: Simple API for complex multimedia operations

This system enables the creation of high-performance multimedia applications with perfect timing coordination across all subsystems, optimized for Apple Silicon's unified memory architecture.
