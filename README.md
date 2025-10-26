# MetalHead

A high-performance macOS multimedia engine with 3D acceleration, 2D drawing, audio processing, and input handling, optimized for Apple Silicon with Metal 4.

## Features

- **Metal 4 Rendering**: Hardware-accelerated 3D graphics with ray tracing support
- **3D Model Loading**: Automatic loading of OBJ, USDZ, and other formats via MetalKit and Model I/O
- **PBR Materials**: Physically-based rendering with texture support (Albedo, Normal, Roughness, Metallic)
- **2D Graphics**: Efficient 2D drawing operations
- **Real-time Audio**: Low-latency audio processing with FFT analysis and 3D spatial audio
- **Input Handling**: Keyboard, mouse, and gamepad support
- **Dynamic Memory Management**: Custom memory allocator with precise alignment for Apple Silicon
- **Unified Clock System**: Synchronized timing across all subsystems with latency compensation
- **Performance Monitoring**: Real-time metrics for frame rate, memory, CPU, and GPU usage

## Requirements

- macOS 13.0 or later
- Apple Silicon (ARM64) processor
- Metal 4 compatible GPU
- Swift 6.0+

## Installation

### Using Xcode

1. Open `MetalHead.xcodeproj` in Xcode
2. Select the "MetalHead" scheme
3. Build and run (⌘R)

### Using Make

```bash
make build    # Build the project
make test     # Run unit tests
make lint     # Run SwiftLint
make clean    # Clean build artifacts
make release  # Build for release
```

## Architecture

The engine is organized into modular components:

### Core Systems
- **MetalRenderingEngine**: 3D rendering with Metal 4 and model loading
- **ModelLoader**: 3D model loading with MetalKit (OBJ, USDZ, etc.) and PBR materials
- **Graphics2D**: 2D drawing operations
- **AudioEngine**: Real-time audio processing
- **InputManager**: Keyboard, mouse, and gamepad input
- **MemoryManager**: Dynamic memory allocation with alignment
- **UnifiedClockSystem**: Master clock for synchronization

### Utilities
- **SIMDExtensions**: SIMD type extensions
- **PerformanceMonitor**: Performance metrics tracking
- **ErrorHandler**: Comprehensive error handling
- **Logger**: Structured logging system

## Usage

### Basic Setup

```swift
import MetalHead

let engine = UnifiedMultimediaEngine()
try await engine.start()
```

### Rendering 3D Objects

```swift
// Render primitive objects
let renderingEngine = engine.getSubsystem(MetalRenderingEngine.self)
renderingEngine?.renderCube(at: SIMD3<Float>(0, 0, -5))

// Load and render 3D models
if let modelURL = Bundle.main.url(forResource: "myModel", withExtension: "obj") {
    let mesh = try renderingEngine?.loadModel(from: modelURL)
    // Render the loaded mesh
}

// Load PBR materials
let material = try renderingEngine?.loadPBRMaterial(
    baseColor: bundleURL(forResource: "albedo.png"),
    normal: bundleURL(forResource: "normal.png"),
    roughness: bundleURL(forResource: "roughness.png"),
    metallic: bundleURL(forResource: "metallic.png")
)
```

### Audio Playback

```swift
let audioEngine = engine.getSubsystem(AudioEngine.self)
audioEngine?.play()
audioEngine?.setVolume(0.5)
```

### Input Handling

```swift
let inputManager = engine.getSubsystem(InputManager.self)
inputManager?.keyboardEvents
    .sink { event in
        print("Key: \(event.keyCode)")
    }
```

## Project Structure

```
MetalHead/
├── Core/
│   ├── Rendering/        # 3D and 2D rendering
│   │   ├── MetalRenderingEngine.swift
│   │   ├── ModelLoader.swift      # 3D model loading with MetalKit
│   │   ├── Graphics2D.swift
│   │   └── Shaders.metal
│   ├── Audio/            # Audio processing
│   ├── Input/            # Input handling
│   ├── Memory/           # Memory management
│   ├── Synchronization/  # Clock system
│   └── UnifiedMultimediaEngine.swift
├── Utilities/
│   ├── Extensions/       # SIMD extensions
│   ├── Performance/     # Performance monitoring
│   ├── ErrorHandling/   # Error handling
│   └── Logging/         # Logging system
└── MetalHeadApp.swift   # App entry point
```

## Testing

### Built-in Testing API

The engine includes a comprehensive Testing API to verify all subsystems are functioning:

```swift
// Run a complete health check
let engine = UnifiedMultimediaEngine()
let reports = await engine.runHealthCheck()

// Or use the TestAPI directly for continuous monitoring
let testAPI = TestAPI()
testAPI.startMonitoring(engine: engine, interval: 5.0)

// Verify all subsystems are available
if engine.verifySubsystems() {
    print("All subsystems ready")
}
```

The health check tests:
- Metal GPU support and capabilities
- Memory allocation and management
- Rendering engine pipeline
- Audio engine functionality
- Input manager readiness
- Clock synchronization
- Performance monitoring

### Unit Tests

Comprehensive unit and performance tests are included:

```bash
make test              # Run all tests
make test-unit         # Run unit tests only
make test-performance  # Run performance tests
```

Tests are automatically run after each build when `TEST_AFTER_BUILD` is enabled.

## Configuration

### Build Settings

- **Architecture**: ARM64 only (Apple Silicon)
- **Swift Version**: 6.0
- **Treat Warnings as Errors**: Enabled
- **Test Execution Time Allowance**: 10 seconds

### Performance Tuning

Adjust frame rate and memory settings in `UnifiedMultimediaEngine`:

```swift
engine.configureFrameRate(60)
engine.configureMemoryPool(size: 256 * 1024 * 1024)
```

## Contributing

This is an enterprise-grade engine with strict code quality requirements:

- All warnings are treated as errors
- Code must compile for Apple Silicon only
- Comprehensive unit test coverage required
- Performance metrics must pass benchmarks

## License

Proprietary - All Rights Reserved

## Support

For issues, feature requests, or contributions, please contact the development team.

