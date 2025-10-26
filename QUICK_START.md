# MetalHead Quick Start

Get started with MetalHead in 5 minutes!

---

## ⚡ Quick Start

### 1. Open in Xcode
```bash
open MetalHead.xcodeproj
```

### 2. Build and Run
```bash
# Or press Command + B to build
# Then Command + R to run
```

---

## 📖 Essential Documentation

| Document | Purpose |
|----------|---------|
| **[USAGE_GUIDE.md](USAGE_GUIDE.md)** | Step-by-step tutorials for all features |
| **[API_REFERENCE.md](API_REFERENCE.md)** | Complete API with all functions |
| [README.md](README.md) | Project overview and features |
| [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) | Architecture details |
| [BUILD_SYSTEM.md](BUILD_SYSTEM.md) | Build and test system |

---

## 🎯 Most Common Tasks

### Start the Engine
```swift
let engine = UnifiedMultimediaEngine()
try await engine.initialize()
try await engine.start()
```

### Render 3D Scene
```swift
guard let rendering = engine.getSubsystem(MetalRenderingEngine.self) else { return }
rendering.toggle3DMode()
rendering.render(deltaTime: 1.0/120.0, in: view)
```

### Play Audio
```swift
guard let audio = engine.getSubsystem(AudioEngine.self) else { return }
audio.play()
audio.setVolume(0.8)
```

### Handle Input
```swift
guard let input = engine.getSubsystem(InputManager.self) else { return }
input.captureMouse()
if input.isKeyPressed("jump") {
    player.jump()
}
```

### Monitor Performance
```swift
guard let monitor = engine.getSubsystem(PerformanceMonitor.self) else { return }
let report = monitor.getPerformanceReport()
print("FPS: \(report.fps)")
```

---

## 🚀 Next Steps

1. Read [USAGE_GUIDE.md](USAGE_GUIDE.md) for complete tutorials
2. Check [API_REFERENCE.md](API_REFERENCE.md) for all available functions
3. Explore the examples in documentation
4. Start building your multimedia app!

---

**Happy Coding! 🎉**
