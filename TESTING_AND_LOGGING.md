# Testing and Logging in MetalHead

## Overview

MetalHead implements a comprehensive testing and logging framework to ensure reliability, maintainability, and observability of the multimedia engine.

---

## Logging System

### Architecture

The logging system uses **OSLog** (Apple's unified logging framework) with structured categories and multiple log levels.

### Log Categories

Each subsystem has its own dedicated log category:

```swift
- Rendering: com.metalhead.rendering
- Audio: com.metalhead.audio
- Input: com.metalhead.input
- Memory: com.metalhead.memory
- Clock: com.metalhead.clock
- Performance: com.metalhead.performance
- Error: com.metalhead.error
- Ray Tracing: com.metalhead.raytracing
- Geometry: com.metalhead.geometry
```

### Log Levels

Five log levels for granular control:

```swift
public enum LogLevel: String {
    case debug = "DEBUG"      // Detailed debugging information
    case info = "INFO"        // General informational messages
    case warning = "WARNING"  // Warning messages
    case error = "ERROR"      // Error conditions
    case fault = "FAULT"      // Critical system failures
}
```

### Usage Examples

#### Basic Logging

```swift
// Category-specific logging
Logger.shared.logRendering("Frame rendered", level: .info)
Logger.shared.logAudio("Playback started", level: .info)
Logger.shared.logMemory("Allocated 100MB", level: .info)

// Static convenience methods
Logger.rendering("Pipeline created", level: .debug)
Logger.audio("Buffer size: 1024", level: .debug)
Logger.performance("FPS: 120", level: .info)
```

#### Error Logging with Context

```swift
let error = NSError(domain: "MetalHead", code: 100, userInfo: nil)
Logger.shared.logError("Rendering failed", error: error)

// With additional context
Logger.shared.logErrorWithContext(
    "Memory allocation failed",
    context: [
        "size": "1024MB",
        "alignment": "16",
        "type": "vertex"
    ],
    error: error
)
```

#### Performance Timing

```swift
// Manual timing
let startTime = Logger.shared.startTimer(label: "RenderFrame")
// ... rendering code ...
Logger.shared.endTimer(label: "RenderFrame", startTime: startTime)

// Automatic timing with defer
let result = Logger.shared.measureTime("LoadModel") {
    return try modelLoader.loadModel(from: url)
}
```

#### Memory Logging

```swift
// Log current memory usage
Logger.shared.logMemoryUsage()
// Output: [12:34:56.789] INFO: Current memory: 256.5 MB
```

#### Frame Logging

```swift
// Log frame rate (automatically throttled to 1 second intervals)
Logger.shared.logFrame()
// Output: [12:34:56.789] INFO: FPS: 120
```

### Log Configuration

```swift
// Enable verbose output (prints to console)
Logger.shared.isVerbose = true

// Enable debug logs
Logger.shared.isDebug = true

// Production mode (only errors and faults)
Logger.shared.isProduction = true
```

### Log Format

All logs include:
- **Timestamp**: `[HH:mm:ss.SSS]`
- **Level**: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `FAULT`
- **Message**: The actual log message

Example output:
```
[12:34:56.789] INFO: Frame rendered
[12:34:56.790] DEBUG: Pipeline state created
[12:34:56.791] WARNING: Low frame rate detected
[12:34:56.792] ERROR: Memory allocation failed: Out of memory
```

### Persistent Storage

Logs are automatically stored by macOS's unified logging system:
- Accessible via Console.app
- Searchable and filterable
- Persistent across app restarts
- Integrated with system monitoring tools

---

## Testing System

### Test Structure

MetalHead has **19 test files** covering all subsystems:

```
MetalHeadTests/
├── MetalHeadTests.swift              # Main engine tests
├── UnifiedEngineTests.swift          # Unified engine lifecycle
├── RenderingEngineTests.swift       # 3D rendering tests
├── Graphics2DTests.swift            # 2D graphics tests
├── AudioEngineTests.swift           # Audio engine tests
├── InputManagerTests.swift         # Input handling tests
├── MemoryManagerTests.swift        # Memory management tests
├── ClockSystemTests.swift          # Clock synchronization tests
├── PerformanceTests.swift          # Performance benchmarks
├── LoggerTests.swift               # Logging system tests
├── ModelLoaderTests.swift          # 3D model loading tests
├── ComputeShaderManagerTests.swift # Compute shader tests
├── OffscreenRendererTests.swift    # Offscreen rendering tests
├── TextureManagerTests.swift       # Texture management tests
├── RayTracingTests.swift           # Ray tracing tests
├── GeometryShaderTests.swift       # Geometry generation tests
├── TestAPITests.swift              # Testing API tests
├── EnhancedBuildTests.swift        # Build verification tests
└── TestConfiguration.swift         # Test configuration
```

### TestAPI - Programmatic Testing

The `TestAPI` class provides a programmatic way to verify system health:

#### Health Check

```swift
let engine = UnifiedMultimediaEngine()
try await engine.initialize()

// Run complete health check
let reports = await engine.runHealthCheck()

// Or use TestAPI directly
let testAPI = TestAPI()
let reports = await testAPI.runHealthCheck(engine: engine)

// Reports include:
// - Subsystem name
// - Test name
// - Result (passed/failed/skipped/warning)
// - Duration
// - Optional message
```

#### Health Check Output

```
=== MetalHead Health Check ===

✓ PASSED - Metal: Device Support (0.001s)
  GPU: Apple M2 Pro

✓ PASSED - Memory: Allocation (0.002s)
  Total: 268435456 bytes, Active: 1

✓ PASSED - Rendering: Pipeline Ready (0.005s)
  3D rendering pipeline initialized

✓ PASSED - Audio: Volume Control (0.001s)
  Volume: 0.50

✓ PASSED - Input: Manager Ready (0.001s)
  Keyboard, mouse, and gamepad support active

✓ PASSED - Clock: Synchronization (0.001s)
  Latency: 0.003s

✓ PASSED - Performance: Monitoring Active (0.001s)
  Tracking: FPS, Memory, CPU, GPU

=== Summary ===
Total: 7 | Passed: 7 | Failed: 0 | Warnings: 0
```

#### Continuous Monitoring

```swift
// Start continuous health monitoring (every 5 seconds)
testAPI.startMonitoring(engine: engine, interval: 5.0)

// Output:
[Quick Health Check]
  ✓ Rendering
  ✓ Ray Tracing
  ✓ Audio
  ✓ Input
  ✓ Memory
  ✓ Clock
  ✓ Performance
```

#### Subsystem Verification

```swift
// Quick verification
if engine.verifySubsystems() {
    print("All subsystems ready")
} else {
    print("Some subsystems missing")
}
```

### Unit Test Examples

#### Rendering Engine Tests

```swift
func test_RenderingEngine_whenInitialized_expectPipelineReady() async throws {
    // Given
    let device = MTLCreateSystemDefaultDevice()!
    let engine = MetalRenderingEngine(device: device)
    
    // When
    try await engine.initialize()
    
    // Then
    XCTAssertTrue(engine.fps >= 0, "FPS should be tracked")
}
```

#### Memory Manager Tests

```swift
func test_MemoryAllocation_whenValid_expectSuccess() {
    // Given
    let manager = MemoryManager(device: device)
    
    // When
    let ptr = manager.allocate(size: 1024, alignment: 16, type: .vertex)
    
    // Then
    XCTAssertNotNil(ptr, "Allocation should succeed")
    
    // Cleanup
    if let ptr = ptr {
        manager.deallocate(ptr)
    }
}
```

#### Audio Engine Tests

```swift
func test_AudioVolume_whenSet_expectUpdated() {
    // Given
    let audioEngine = AudioEngine()
    
    // When
    audioEngine.setVolume(0.75)
    
    // Then
    XCTAssertEqual(audioEngine.volume, 0.75, accuracy: 0.01)
}
```

### Test Results

Each test provides:
- **Test Name**: Descriptive name following pattern `test_When_Expect`
- **Result**: Pass/Fail with detailed error messages
- **Duration**: Execution time for performance tracking
- **Assertions**: Clear expectations with descriptive messages

### Running Tests

#### Command Line

```bash
# Run all tests
make test

# Run specific test suite
xcodebuild test -scheme MetalHead -destination 'platform=macOS,arch=arm64'
```

#### Xcode

- Press `⌘U` to run all tests
- Click test diamond icons to run individual tests
- View test results in Test Navigator

#### Automatic Testing

Tests are automatically run after each build when `TEST_AFTER_BUILD = YES` is enabled in the project settings.

### Test Coverage

The test suite covers:

✅ **Engine Lifecycle**
- Initialization
- Start/Stop/Pause/Resume
- State transitions

✅ **Subsystem Integration**
- All subsystems accessible
- Proper initialization order
- Error handling

✅ **Performance**
- Frame rate tracking
- Memory usage
- CPU/GPU utilization
- Rendering performance

✅ **Error Handling**
- Invalid inputs
- Resource failures
- Graceful degradation

✅ **Concurrency**
- Thread safety
- Async operations
- Actor isolation

---

## Integration with Development Workflow

### During Development

```swift
// Enable verbose logging during development
Logger.shared.isVerbose = true
Logger.shared.isDebug = true

// Log important operations
Logger.rendering("Starting render pass", level: .info)
Logger.performance("Frame time: \(frameTime)ms", level: .debug)
```

### In Production

```swift
// Only log errors and faults
Logger.shared.isProduction = true
Logger.shared.isVerbose = false
Logger.shared.isDebug = false
```

### Continuous Monitoring

```swift
// Start monitoring in production
let testAPI = TestAPI()
testAPI.startMonitoring(engine: engine, interval: 30.0)

// Health checks run automatically every 30 seconds
// Logs any subsystem failures
```

---

## Best Practices

### Logging

1. **Use appropriate log levels**
   - `debug`: Detailed debugging info
   - `info`: Normal operations
   - `warning`: Potential issues
   - `error`: Error conditions
   - `fault`: Critical failures

2. **Include context**
   ```swift
   Logger.shared.logErrorWithContext(
       "Allocation failed",
       context: ["size": size, "type": type],
       error: error
   )
   ```

3. **Use category-specific methods**
   ```swift
   Logger.rendering("Frame rendered")  // ✅ Good
   Logger.shared.log("Frame rendered", category: renderingLog)  // ✅ Also good
   ```

### Testing

1. **Follow naming convention**
   - `test_When_Expect` pattern
   - Descriptive test names

2. **Use Given-When-Then structure**
   ```swift
   func test_Feature_whenCondition_expectResult() {
       // Given
       let input = ...
       
       // When
       let result = ...
       
       // Then
       XCTAssertEqual(result, expected)
   }
   ```

3. **Clean up resources**
   ```swift
   override func tearDownWithError() throws {
       // Cleanup
       resource = nil
       try super.tearDownWithError()
   }
   ```

---

## Summary

MetalHead's testing and logging systems provide:

✅ **Comprehensive Logging**
- 9 log categories
- 5 log levels
- Performance timing
- Memory tracking
- Error context

✅ **Extensive Testing**
- 19 test files
- Programmatic health checks
- Continuous monitoring
- Performance benchmarks

✅ **Production Ready**
- OSLog integration
- Persistent storage
- Configurable verbosity
- Automated testing

The systems work together to ensure reliability, maintainability, and observability throughout the development and production lifecycle.

