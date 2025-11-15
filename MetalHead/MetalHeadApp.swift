import SwiftUI
import MetalHeadEngine

@main
struct MetalHeadApp: App {
    @StateObject private var unifiedEngine = UnifiedMultimediaEngine()
    @State private var initError: String? = nil
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(unifiedEngine)
                .onAppear {
                    // Initialize when view appears
                    Task { @MainActor in
                        await initializeEngine()
                    }
                }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
    
    @MainActor
    private func initializeEngine() async {
        print("🚀 MetalHeadApp.initializeEngine() called")
        do {
            print("   Step 1: Initializing engine...")
            try await unifiedEngine.initialize()
            print("   ✅ Engine initialized - isInitialized=\(unifiedEngine.isInitialized)")
            
            print("   Step 2: Starting engine...")
            try await unifiedEngine.start()
            print("   ✅ Engine started - isRunning=\(unifiedEngine.isRunning)")
            
            // Add objects
            print("   Step 3: Adding test objects...")
            if let renderingEngine = unifiedEngine.getSubsystem(MetalRenderingEngine.self) {
                renderingEngine.renderCube(at: SIMD3<Float>(0, 0, 0))
                renderingEngine.renderCube(at: SIMD3<Float>(2, 0, 0))
                renderingEngine.renderSphere(at: SIMD3<Float>(-2, 0, 0), radius: 0.5)
                print("   ✅ Test objects added")
            } else {
                print("   ⚠️ Rendering engine not available")
            }
            print("✅ Initialization complete!")
        } catch {
            initError = "\(error)"
            print("❌ INITIALIZATION ERROR: \(error)")
            print("   Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("   Domain: \(nsError.domain), Code: \(nsError.code)")
                print("   Description: \(nsError.localizedDescription)")
            }
        }
    }
}
