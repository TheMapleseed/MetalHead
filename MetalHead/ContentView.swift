import SwiftUI
import MetalKit
import Combine

struct ContentView: View {
    @EnvironmentObject var unifiedEngine: UnifiedMultimediaEngine
    
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
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                HStack {
                    Button("Toggle 3D") {
                        if let renderingEngine = unifiedEngine.getSubsystem(MetalRenderingEngine.self) {
                            renderingEngine.toggle3DMode()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Toggle 2D") {
                        if let renderingEngine = unifiedEngine.getSubsystem(MetalRenderingEngine.self) {
                            renderingEngine.toggle2DMode()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Toggle Audio") {
                        if let audioEngine = unifiedEngine.getSubsystem(AudioEngine.self) {
                            if audioEngine.isPlaying {
                                audioEngine.stop()
                            } else {
                                audioEngine.play()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .background(Color.black)
        .onAppear {
            setupInputHandling()
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
        
        if let renderingEngine = unifiedEngine.getSubsystem(MetalRenderingEngine.self) {
            metalView.device = renderingEngine.device
        }
        
        metalView.delegate = context.coordinator
        metalView.preferredFramesPerSecond = 120
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.sampleCount = 4
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        // Enable input tracking
        metalView.allowedTouchTypes = []
        
        return metalView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Update view if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalView
        var lastTime: CFTimeInterval = 0
        
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
            let deltaTime = currentTime - lastTime
            lastTime = currentTime
            
            parent.unifiedEngine.render(deltaTime: deltaTime, in: view)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(UnifiedMultimediaEngine())
}
