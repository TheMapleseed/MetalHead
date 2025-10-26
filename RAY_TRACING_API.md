# Metal 4 Ray Tracing API

Hardware-accelerated ray tracing for M2 Ultra, M3 Pro/Max/Ultra, and M4 chips.

---

## 🚀 Quick Start

```swift
// Check for ray tracing support
guard let rayTracing = engine.getSubsystem(MetalRayTracingEngine.self) else {
    print("Ray tracing not supported on this device")
    return
}

// Initialize ray tracing
try await rayTracing.initialize()
rayTracing.isEnabled = true

// Configure ray tracing
rayTracing.setRayCount(1_000_000)  // 1 million rays
rayTracing.setBounceCount(3)       // 3 bounces
rayTracing.setSampleCount(1)        // 1 sample per pixel
```

---

## 🎯 Ray Tracing API

### MetalRayTracingEngine

Hardware-accelerated ray tracing implementation.

#### Properties
```swift
@Published var isEnabled: Bool        // Ray tracing enabled
@Published var rayCount: UInt32       // Number of rays per frame
@Published var bounces: UInt32         // Maximum ray bounces
@Published var samples: UInt32        // Samples per pixel
```

#### Initialization
```swift
let rayTracing = MetalRayTracingEngine(device: metalDevice)
try await rayTracing.initialize()
```

#### Configuration
```swift
// Set ray count (resolution)
rayTracing.setRayCount(1920 * 1080)  // Full HD

// Set bounce count (lighting quality)
rayTracing.setBounceCount(5)  // High quality

// Set sample count (antialiasing)
rayTracing.setSampleCount(4)  // 4x MSAA
```

#### Adding Geometry
```swift
// Create a sphere for ray tracing
let sphereGeometry = RTGeometry(
    type: .sphere,
    vertices: sphereVertices,
    indices: nil,
    bounds: AABB(min: SIMD3<Float>(-1, -1, -1), max: SIMD3<Float>(1, 1, 1))
)

rayTracing.addGeometry(sphereGeometry)
```

#### Adding Materials
```swift
// Create a metallic material
let material = RTMaterial(
    albedo: SIMD3<Float>(0.8, 0.8, 0.8),  // Base color
    roughness: 0.1,                        // Smooth surface
    metallic: 1.0,                         // Fully metallic
    emission: SIMD3<Float>(0, 0, 0)        // No emission
)

rayTracing.addMaterial(material)
```

#### Adding Lights
```swift
// Create a point light
let light = RTLight(
    position: SIMD3<Float>(0, 5, 0),
    color: SIMD3<Float>(1, 1, 1),
    intensity: 1.0,
    type: .point
)

rayTracing.addLight(light)
```

#### Tracing Rays
```swift
// In your render loop
func render(commandBuffer: MTLCommandBuffer) {
    if rayTracing.isEnabled {
        rayTracing.traceRays(commandBuffer: commandBuffer)
    }
}
```

#### Performance Metrics
```swift
// Get ray tracing performance
let metrics = rayTracing.getPerformanceMetrics()
print("Total rays: \(metrics.totalRays)")
print("Bounce count: \(metrics.bounceCount)")
print("Sample count: \(metrics.sampleCount)")
```

---

## 🎨 Geometry Library API

### Pre-built Geometries

#### Create a Cube
```swift
let geometryShaders = GeometryShaders(device: metalDevice)
let (vertices, indices) = geometryShaders.createCube()

// Use in rendering
updateVertexBuffer(vertices)
updateIndexBuffer(indices)
```

#### Create a Sphere
```swift
// Create sphere with custom segments
let (vertices, indices) = geometryShaders.createSphere(segments: 64)  // High detail

// Or use default
let (simpleSphere, indices) = geometryShaders.createSphere()
```

#### Create a Plane
```swift
let (vertices, indices) = geometryShaders.createPlane(width: 10, height: 10)
```

#### Create a Cylinder
```swift
let (vertices, indices) = geometryShaders.createCylinder(segments: 32, height: 2.0)
```

#### Create a Torus
```swift
let (vertices, indices) = geometryShaders.createTorus(
    majorRadius: 1.0,
    minorRadius: 0.5,
    segments: 32
)
```

#### Create a Quad
```swift
let (vertices, indices) = geometryShaders.createQuad(size: 1.0)
```

#### Create a Dome
```swift
let (vertices, indices) = geometryShaders.createDome(segments: 32)
```

#### Create a Custom Box
```swift
let (vertices, indices) = geometryShaders.createBox(
    width: 2.0,
    height: 1.0,
    depth: 3.0
)
```

#### Create a Grid
```swift
let (vertices, indices) = geometryShaders.createGrid(
    size: 10.0,
    divisions: 20
)
```

---

## 🔧 API Functions

### Exposed Individual APIs

All geometry functions are individually exposed:

```swift
// Direct function calls (no need to create GeometryShaders instance)
let (cubeVertices, cubeIndices) = createCubeGeometry()
let (sphereVertices, sphereIndices) = createSphereGeometry(segments: 32)
let (planeVertices, planeIndices) = createPlaneGeometry()
let (cylinderVertices, cylinderIndices) = createCylinderGeometry(segments: 16)
let (boxVertices, boxIndices) = createBoxGeometry(width: 2, height: 2, depth: 2)
```

---

## 📊 Complete Example

```swift
import MetalHead

class RayTracingRenderer {
    var rayTracing: MetalRayTracingEngine!
    var geometryShaders: GeometryShaders!
    
    func initialize(device: MTLDevice) async throws {
        // Initialize ray tracing
        rayTracing = MetalRayTracingEngine(device: device)
        try await rayTracing.initialize()
        
        // Create geometry
        let (sphereVertices, sphereIndices) = geometryShaders.createSphere(segments: 64)
        
        let geometry = RTGeometry(
            type: .sphere,
            vertices: sphereVertices,
            indices: sphereIndices,
            bounds: AABB(
                min: SIMD3<Float>(-1, -1, -1),
                max: SIMD3<Float>(1, 1, 1)
            )
        )
        
        rayTracing.addGeometry(geometry)
        
        // Add material
        let material = RTMaterial(
            albedo: SIMD3<Float>(0.8, 0.2, 0.2),
            roughness: 0.3,
            metallic: 0.8
        )
        
        rayTracing.addMaterial(material)
        
        // Add light
        let light = RTLight(
            position: SIMD3<Float>(0, 10, 0),
            color: SIMD3<Float>(1, 1, 1),
            intensity: 2.0,
            type: .point
        )
        
        rayTracing.addLight(light)
        
        // Configure
        rayTracing.setRayCount(1920 * 1080)
        rayTracing.setBounceCount(5)
        rayTracing.setSampleCount(4)
        rayTracing.isEnabled = true
    }
    
    func render(commandBuffer: MTLCommandBuffer) {
        if rayTracing.isEnabled {
            rayTracing.traceRays(commandBuffer: commandBuffer)
        }
    }
}
```

---

## 🎯 Supported Devices

### Metal 4 Ray Tracing Support
- ✅ **M2 Ultra** - Full ray tracing support
- ✅ **M3 Pro** - Full ray tracing support
- ✅ **M3 Max** - Full ray tracing support
- ✅ **M3 Ultra** - Full ray tracing support
- ✅ **M4** - Full ray tracing support

### Checking for Support
```swift
func supportsRayTracing(device: MTLDevice) -> Bool {
    return device.supportsFamily(.apple8) || device.supportsFamily(.apple9)
}
```

---

## 📈 Performance Guidelines

### Ray Count Recommendations
- **720p** (1280×720): 922,560 rays
- **1080p** (1920×1080): 2,073,600 rays
- **1440p** (2560×1440): 3,686,400 rays
- **4K** (3840×2160): 8,294,400 rays

### Bounce Count
- **Low Quality**: 1 bounce
- **Medium Quality**: 3 bounces
- **High Quality**: 5 bounces
- **Ultra Quality**: 8 bounces

### Sample Count
- **No AA**: 1 sample
- **2x MSAA**: 2 samples
- **4x MSAA**: 4 samples
- **8x MSAA**: 8 samples

---

## 🎨 Geometry Best Practices

### Level of Detail (LOD)
```swift
// High detail for close objects
let highDetail = geometryShaders.createSphere(segments: 64)

// Medium detail for mid-distance
let mediumDetail = geometryShaders.createSphere(segments: 32)

// Low detail for far objects
let lowDetail = geometryShaders.createSphere(segments: 16)
```

### Geometry Reuse
```swift
// Create once, reuse multiple times
let cubeGeometry = createCubeGeometry()

// Use for multiple instances
for position in positions {
    drawInstance(geometry: cubeGeometry, transform: position)
}
```

---

## 📚 Additional Resources

- [Metal Programming Guide](https://developer.apple.com/documentation/metal)
- [Ray Tracing Guidelines](https://developer.apple.com/metal/)
- [Geometry Optimization](https://developer.apple.com/documentation/metal/optimizing_metal_apps)

---

**Metal 4 Ray Tracing** - Hardware-accelerated real-time ray tracing on Apple Silicon
