# MetalHeadEngine Test Suite

## Overview
Comprehensive test suite for the MetalHeadEngine framework, covering all subsystems and integration points.

## Test Structure

### Framework Configuration
- **Framework**: `MetalHeadEngine`
- **Import**: `@testable import MetalHeadEngine`
- **Target**: `MetalHeadTests`
- **Dependencies**: Links against `MetalHeadEngine.framework`

## Test Files

### Core Engine Tests
1. **MetalHeadTests.swift** - Main test suite
   - Engine initialization
   - Subsystem access
   - Performance metrics
   - Error handling

2. **UnifiedEngineTests.swift** - UnifiedMultimediaEngine tests
   - Lifecycle management (initialize, start, stop, pause, resume)
   - Subsystem access and registration
   - Performance metrics
   - Concurrent access safety
   - Synchronization quality

### Rendering Tests
3. **RenderingEngineTests.swift** - MetalRenderingEngine tests
   - 3D rendering pipeline
   - Mode switching (2D/3D)
   - Scene object management
   - Camera and projection
   - FPS tracking

4. **Graphics2DTests.swift** - Graphics2D tests
   - 2D rendering primitives
   - Sprite rendering
   - Text rendering
   - Transformations

5. **ModelLoaderTests.swift** - ModelLoader tests
   - Model loading from files
   - Mesh caching
   - Material handling
   - Error handling

6. **GeometryShaderTests.swift** - GeometryShaders tests
   - Cube generation
   - Sphere generation
   - Plane generation
   - Cylinder generation

7. **RayTracingTests.swift** - MetalRayTracingEngine tests
   - Ray tracing initialization
   - Acceleration structure creation
   - Shader table setup
   - Ray tracing execution

8. **ComputeShaderManagerTests.swift** - ComputeShaderManager tests
   - Compute pipeline creation
   - Buffer management
   - Threadgroup configuration

9. **OffscreenRendererTests.swift** - OffscreenRenderer tests
   - Render target creation
   - Offscreen rendering
   - Texture output

10. **DeferredRendererTests.swift** - DeferredRenderer tests
    - G-Buffer creation
    - Deferred lighting
    - Multiple light sources

11. **TextureManagerTests.swift** - TextureManager tests
    - Texture loading
    - Texture caching
    - Mipmap generation

### Audio Tests
12. **AudioEngineTests.swift** - AudioEngine tests
    - Audio initialization
    - Playback control
    - Volume management
    - Audio format handling

### Input Tests
13. **InputManagerTests.swift** - InputManager tests
    - Keyboard input
    - Mouse input
    - Action mapping
    - Input event publishing

### Memory Tests
14. **MemoryManagerTests.swift** - MemoryManager tests
    - Vertex data allocation
    - Uniform data allocation
    - Audio data allocation
    - Texture data allocation
    - Memory deallocation
    - Memory reports

### Synchronization Tests
15. **ClockSystemTests.swift** - UnifiedClockSystem tests
    - Clock initialization
    - Time tracking
    - Synchronization
    - Pause/resume

### Utility Tests
16. **LoggerTests.swift** - Logger tests
    - Logging categories
    - Log levels
    - Performance logging
    - Memory logging

17. **PerformanceTests.swift** - PerformanceMonitor tests
    - Performance metrics
    - Frame rate tracking
    - Memory usage tracking
    - CPU utilization

### Integration Tests
18. **TestAPITests.swift** - TestAPI tests
    - Health check execution
    - Subsystem verification
    - Test report generation

19. **EnhancedBuildTests.swift** - Enhanced build verification
    - Full system integration
    - Thread safety
    - Memory leak detection
    - Build verification

### Configuration
20. **TestConfiguration.swift** - Test utilities and configuration
    - Test constants and thresholds
    - Mock objects
    - Test data generators
    - Performance assertions
    - Memory assertions
    - Error assertions

## Test Utilities

### TestConfiguration Class
Provides:
- Test constants (timeouts, thresholds)
- Test data generators (vertices, uniforms, audio data)
- Performance measurement utilities
- Memory measurement utilities
- Error assertion helpers

### Mock Objects
- `MockRenderingEngine` - Mock rendering engine
- `MockAudioEngine` - Mock audio engine
- `MockInputManager` - Mock input manager
- `MockMemoryManager` - Mock memory manager
- `MockClockSystem` - Mock clock system

## Test Execution

### Running Tests
```bash
# Run all tests
xcodebuild test -project MetalHead.xcodeproj -scheme MetalHead

# Run specific test
xcodebuild test -project MetalHead.xcodeproj -scheme MetalHead -only-testing:MetalHeadTests/MetalHeadTests/testUnifiedEngineInitialization
```

### Test Coverage
- Unit tests for all subsystems
- Integration tests for engine orchestration
- Performance tests for critical paths
- Thread safety tests for concurrent access
- Error handling tests for all error paths

## Framework Dependencies

All tests import:
```swift
@testable import MetalHeadEngine
```

This provides access to:
- All public APIs
- Internal APIs (via @testable)
- Framework types (Vertex, Uniforms, etc.)
- Framework errors (RenderingError, etc.)

## Test Best Practices

1. **Async/Await**: Use async/await for async operations
2. **Main Actor**: Respect @MainActor isolation for engine classes
3. **Timeouts**: Use TestConfiguration timeouts for async operations
4. **Cleanup**: Properly tear down resources in tearDown
5. **Isolation**: Each test should be independent
6. **Mocking**: Use mock objects for complex dependencies

## Notes

- Tests use `@testable import MetalHeadEngine` to access internal APIs
- Some tests require Metal device availability
- Performance tests may vary based on hardware
- Thread safety tests verify concurrent access patterns

