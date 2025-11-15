import SwiftUI
import MetalKit
import Combine
import MetalHeadEngine

struct ContentView: View {
    @EnvironmentObject var unifiedEngine: UnifiedMultimediaEngine
    @State private var audioButtonText = "Toggle Audio"
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            // Metal rendering view
            MetalView()
                .environmentObject(unifiedEngine)
            
            // UI overlay
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MetalHead Unified Engine")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("FPS: \(Int(unifiedEngine.frameRate))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Latency: \(String(format: "%.1f", unifiedEngine.systemLatency * 1000))ms")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Sync Quality: \(String(format: "%.1f", unifiedEngine.synchronizationQuality * 100))%")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        // Diagnostic info
                        Text("Engine: \(unifiedEngine.isInitialized ? "✅ Init" : "❌ Not Init") | \(unifiedEngine.isRunning ? "✅ Running" : "❌ Stopped")")
                            .font(.caption)
                            .foregroundColor(unifiedEngine.isInitialized && unifiedEngine.isRunning ? .green : .red)
                        
                        if let renderingEngine = unifiedEngine.getSubsystem(MetalRenderingEngine.self) {
                            Text("Rendering: \(renderingEngine.is3DMode ? "3D" : "2D") | FPS: \(renderingEngine.fps)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            Text("Rendering: ❌ Not Available")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        // Show initialization error if any
                        if !unifiedEngine.isInitialized {
                            Text("Click 'Initialize Engine' button to see error")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                HStack {
                    Button(action: {
                        // Visual feedback that button was clicked
                        alertMessage = "Button clicked! Initializing..."
                        showAlert = true
                        
                        print("🔧🔧🔧 BUTTON CLICKED - ACTION BLOCK EXECUTING")
                        print("   Thread: \(Thread.isMainThread ? "Main" : "Background")")
                        print("   Current state: initialized=\(unifiedEngine.isInitialized), running=\(unifiedEngine.isRunning)")
                        
                        Task { @MainActor in
                            print("   📍 Inside Task @MainActor")
                            do {
                                if !unifiedEngine.isInitialized {
                                    print("   🔧 Starting initialization...")
                                    alertMessage = "Initializing engine..."
                                    try await unifiedEngine.initialize()
                                    print("   ✅ Initialization successful - isInitialized=\(unifiedEngine.isInitialized)")
                                    alertMessage = "Engine initialized! Starting..."
                                } else {
                                    print("   ℹ️ Already initialized")
                                }
                                
                                if !unifiedEngine.isRunning {
                                    print("   🔧 Starting engine...")
                                    try await unifiedEngine.start()
                                    print("   ✅ Engine started - isRunning=\(unifiedEngine.isRunning)")
                                    alertMessage = "Engine started! Adding objects..."
                                } else {
                                    print("   ℹ️ Already running")
                                }
                                
                                // Add test objects
                                if let renderingEngine = unifiedEngine.getSubsystem(MetalRenderingEngine.self) {
                                    print("   🧪 Adding test objects...")
                                    renderingEngine.renderCube(at: SIMD3<Float>(0, 0, 0))
                                    renderingEngine.renderCube(at: SIMD3<Float>(2, 0, 0))
                                    renderingEngine.renderSphere(at: SIMD3<Float>(-2, 0, 0), radius: 0.5)
                                    print("   ✅ Test objects added")
                                    alertMessage = "✅ Success! Engine ready with 3 objects."
                                } else {
                                    print("   ❌ Rendering engine not available")
                                    alertMessage = "❌ Error: Rendering engine not available"
                                }
                            } catch {
                                print("   ❌ Initialization failed: \(error)")
                                print("   Error type: \(type(of: error))")
                                print("   Error details: \(error.localizedDescription)")
                                alertMessage = "❌ Error: \(error.localizedDescription)"
                            }
                            print("   🏁 Task completed")
                            showAlert = true
                        }
                    }) {
                        Text(unifiedEngine.isInitialized && unifiedEngine.isRunning ? "✅ Engine Ready" : "⚠️ Initialize Engine")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Click to initialize and start the engine")
                    
                    Button("Add Cube") {
                        print("🔵 Add Cube button clicked")
                        print("   Engine initialized: \(unifiedEngine.isInitialized)")
                        print("   Engine running: \(unifiedEngine.isRunning)")
                        if let renderingEngine = unifiedEngine.getSubsystem(MetalRenderingEngine.self) {
                            let position = SIMD3<Float>(
                                Float.random(in: -2...2),
                                Float.random(in: -2...2),
                                Float.random(in: -2...2)
                            )
                            renderingEngine.renderCube(at: position)
                            print("✅ Added cube at position: \(position)")
                        } else {
                            print("❌ Rendering engine not available")
                            print("   Subsystems: \(unifiedEngine.getSubsystem(MetalRenderingEngine.self) != nil ? "available" : "not available")")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Add a colored cube to the 3D scene")
                    
                    Button("Add Sphere") {
                        if let renderingEngine = unifiedEngine.getSubsystem(MetalRenderingEngine.self) {
                            let position = SIMD3<Float>(
                                Float.random(in: -2...2),
                                Float.random(in: -2...2),
                                Float.random(in: -2...2)
                            )
                            renderingEngine.renderSphere(at: position, radius: 0.5)
                            print("✅ Added sphere at position: \(position)")
                        } else {
                            print("❌ Rendering engine not available - engine may not be initialized")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Add a sphere to the 3D scene")
                    
                    Button(audioButtonText) {
                        if let audioEngine = unifiedEngine.getSubsystem(AudioEngine.self) {
                            if audioEngine.isPlaying {
                                audioEngine.stop()
                                audioButtonText = "Toggle Audio"
                                print("🔇 Audio stopped")
                            } else {
                                audioEngine.play()
                                audioButtonText = "Stop Audio"
                                print("🔊 Audio playing")
                            }
                        } else {
                            print("❌ Audio engine not available - engine may not be initialized")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Toggle audio playback")
                }
                .padding()
            }
        }
        .background(Color.black)
        .onAppear {
            setupInputHandling()
        }
        .alert("Engine Status", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func setupInputHandling() {
        // Setup input handling through unified engine
        if let inputManager = unifiedEngine.getSubsystem(InputManager.self) {
            // Subscribe to input events
            inputManager.keyboardPublisher
                .sink { keyCode in
                    // Handle keyboard input
                }
                .store(in: &cancellables)
            
            inputManager.mousePublisher
                .sink { mouseEvent in
                    // Handle mouse input
                }
                .store(in: &cancellables)
        }
    }
    
    @State private var cancellables = Set<AnyCancellable>()
    
    private func handleKeyboardInput(_ keyCode: UInt16) {
        switch keyCode {
        case 53: // Escape
            NSApplication.shared.terminate(nil)
        case 49: // Space
            if let renderingEngine = unifiedEngine.getSubsystem(MetalRenderingEngine.self) {
                renderingEngine.toggle3DMode()
            }
        case 17: // T
            if let renderingEngine = unifiedEngine.getSubsystem(MetalRenderingEngine.self) {
                renderingEngine.toggle2DMode()
            }
        case 35: // P
            if let audioEngine = unifiedEngine.getSubsystem(AudioEngine.self) {
                if audioEngine.isPlaying {
                    audioEngine.stop()
                } else {
                    audioEngine.play()
                }
            }
        default:
            break
        }
    }
    
    private func handleMouseInput(_ event: MouseEvent) {
        if let renderingEngine = unifiedEngine.getSubsystem(MetalRenderingEngine.self) {
            switch event.type {
            case .move:
                renderingEngine.updateMousePosition(event.position)
            case .click:
                renderingEngine.handleMouseClick(at: event.position)
            case .release:
                // Handle mouse release
                break
            case .scroll:
                renderingEngine.handleMouseScroll(delta: event.scrollDelta)
            }
        }
    }
}

struct MetalView: NSViewRepresentable {
    @EnvironmentObject var unifiedEngine: UnifiedMultimediaEngine
    
    func makeNSView(context: Context) -> MTKView {
        let metalView = MTKView()
        
        // Use the same device from unified engine - ensures pointer alignment
        metalView.device = unifiedEngine.metalDevice
        
        metalView.delegate = context.coordinator
        metalView.preferredFramesPerSecond = 120
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.sampleCount = 4
        metalView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false
        
        return metalView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Ensure device pointer matches - critical for proper rendering
        if nsView.device !== unifiedEngine.metalDevice {
            nsView.device = unifiedEngine.metalDevice
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalView
        var lastTime: CFTimeInterval = 0
        var frameCount = 0
        
        init(_ parent: MetalView) {
            self.parent = parent
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            if let renderingEngine = parent.unifiedEngine.getSubsystem(MetalRenderingEngine.self) {
                renderingEngine.updateDrawableSize(size)
            }
        }
        
        func draw(in view: MTKView) {
            let currentTime = CACurrentMediaTime()
            var deltaTime = currentTime - lastTime
            if deltaTime <= 0 || lastTime == 0 {
                lastTime = currentTime
                deltaTime = 1.0 / 120.0 // Default to 120 FPS for first frame
            }
            lastTime = currentTime
            
            // Debug first few frames
            if frameCount < 10 {
                print("🎬 Frame \(frameCount): Engine running=\(parent.unifiedEngine.isRunning), initialized=\(parent.unifiedEngine.isInitialized), deltaTime=\(deltaTime)")
            }
            
            parent.unifiedEngine.render(deltaTime: deltaTime, in: view)
            frameCount += 1
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(UnifiedMultimediaEngine())
}
