import SwiftUI
import MetalHeadEngine

@main
struct MetalHeadApp: App {
    @StateObject private var unifiedEngine = UnifiedMultimediaEngine()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(unifiedEngine)
                .onAppear {
                    Task {
                        await initializeUnifiedEngine()
                    }
                }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
    
    @MainActor
    private func initializeUnifiedEngine() async {
        do {
            try await unifiedEngine.initialize()
            try await unifiedEngine.start()
        } catch {
            print("Failed to initialize unified engine: \(error)")
        }
    }
}
