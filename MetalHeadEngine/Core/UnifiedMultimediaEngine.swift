import Foundation
import Metal
import MetalKit
import Combine
import simd

// Import ray tracing engine
// Note: MetalRayTracingEngine is in the same module, so no explicit import needed
// But we need to ensure it's accessible

/// Unified multimedia engine that orchestrates all subsystems
@MainActor
public class UnifiedMultimediaEngine: ObservableObject {
    // MARK: - Properties
    @Published public var isInitialized: Bool = false
    @Published public var isRunning: Bool = false
    @Published public var frameRate: Double = 0
    @Published public var systemLatency: TimeInterval = 0
    @Published public var synchronizationQuality: Float = 0
    
    // Core subsystems
    private let device: MTLDevice
    private var renderingEngine: MetalRenderingEngine?
    private var rayTracingEngine: MetalRayTracingEngine?
    private var graphics2D: Graphics2D?
    private var audioEngine: AudioEngine?
    private var inputManager: InputManager?
    private var memoryManager: MemoryManager?
    private var clockSystem: UnifiedClockSystem?
    private var performanceMonitor: PerformanceMonitor?
    
    // Subsystem registry
    private var subsystems: [String: Any] = [:]
    
    // Performance tracking
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: UInt64 = 0
    private var targetFrameRate: Double = 120.0
    private var memoryPoolSize: Int = 256 * 1024 * 1024 // 256 MB default
    
    // Concurrency
    // Note: Removed DispatchQueue - use Task with proper actor isolation instead
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
        print("✅ UnifiedMultimediaEngine.init() - device created")
    }
    
    // MARK: - Public Interface
    public func initialize() async throws {
        guard !isInitialized else {
            print("⚠️ Engine already initialized")
            return
        }
        
        print("🔧 Setting up subsystems...")
        try await setupSubsystems()
        print("   ✅ Subsystems setup complete")
        
        print("🔧 Setting up synchronization...")
        try await setupSynchronization()
        print("   ✅ Synchronization setup complete")
        
        print("🔧 Setting up performance monitoring...")
        try await setupPerformanceMonitoring()
        print("   ✅ Performance monitoring setup complete")
        
        // Update @Published property - we're already @MainActor
        self.isInitialized = true
        print("✅ Unified Multimedia Engine initialized successfully - isInitialized=\(self.isInitialized)")
        
        // Force UI update - we're already on MainActor, just send the notification
        self.objectWillChange.send()
    }
    
    public func start() async throws {
        guard !isRunning else {
            print("⚠️ Engine already running")
            return
        }
        
        guard isInitialized else {
            throw NSError(domain: "MetalHeadEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Engine must be initialized before starting"])
        }
        
        print("▶️ Starting subsystems...")
        try await startSubsystems()
        print("   ✅ Subsystems started")
        
        startMainLoop()
        print("   ✅ Main loop started")
        
        // Update @Published property - we're already @MainActor
        self.isRunning = true
        print("✅ Unified Multimedia Engine started - isRunning=\(self.isRunning)")
        
        // Force UI update - we're already on MainActor
        self.objectWillChange.send()
    }
    
    public func stop() {
        guard isRunning else { return }
        
        stopSubsystems()
        isRunning = false
        print("Unified Multimedia Engine stopped")
    }
    
    public func pause() {
        guard isRunning else { return }
        
        pauseSubsystems()
        isRunning = false
        print("Unified Multimedia Engine paused")
    }
    
    public func resume() async throws {
        guard !isRunning else { return }
        
        try await resumeSubsystems()
        isRunning = true
        print("Unified Multimedia Engine resumed")
    }
    
    public func getSubsystem<T>(_ type: T.Type) -> T? {
        let typeName = String(describing: type)
        return subsystems[typeName] as? T
    }
    
    public var metalDevice: MTLDevice {
        return device
    }
    
    public func render(deltaTime: CFTimeInterval, in view: MTKView) {
        // Always try to render, even if not "running" - rendering should work if initialized
        guard isInitialized else {
            print("⚠️ Render skipped: Engine not initialized")
            return
        }
        
        // If not running, start it automatically
        if !isRunning {
            print("⚠️ Engine not running, attempting to start...")
            Task { @MainActor in
                do {
                    try await self.start()
                } catch {
                    print("❌ Failed to start engine: \(error)")
                }
            }
            // Continue anyway - rendering should work if subsystems are initialized
        }
        
        let startTime = CACurrentMediaTime()
        
        // Update performance metrics
        performanceMonitor?.recordFrameTime(deltaTime)
        
        // Render 3D scene
        if let renderingEngine = renderingEngine {
            renderingEngine.render(deltaTime: deltaTime, in: view)
        }
        
        // Render 2D overlay (integrated into 3D rendering)
        if graphics2D != nil {
            // 2D rendering will be integrated into the main Metal render pass
            // This happens during the 3D rendering which shares the same pass
        }
        
        // Update frame rate
        frameCount += 1
        if frameCount % 60 == 0 {
            frameRate = 1.0 / deltaTime
        }
        
        // Update system latency
        let renderTime = CACurrentMediaTime() - startTime
        systemLatency = renderTime
        
        // Update synchronization quality
        updateSynchronizationQuality()
    }
    
    public func getPerformanceMetrics() -> PerformanceReport? {
        return performanceMonitor?.getPerformanceReport()
    }
    
    public func getMemoryReport() -> MemoryReport? {
        return memoryManager?.getMemoryReport()
    }
    
    /// Configure the target frame rate for the engine
    public func configureFrameRate(_ fps: Double) {
        guard fps > 0 && fps <= 240 else {
            print("Invalid frame rate: \(fps). Must be between 1 and 240 FPS")
            return
        }
        targetFrameRate = fps
        print("Target frame rate set to \(fps) FPS")
    }
    
    /// Configure the memory pool size for the engine
    public func configureMemoryPool(size: Int) {
        guard size > 0 && size <= 1024 * 1024 * 1024 else {
            print("Invalid memory pool size: \(size). Must be between 1 byte and 1 GB")
            return
        }
        memoryPoolSize = size
        print("Memory pool size set to \(size / (1024 * 1024)) MB")
        // Note: Actual memory pool reconfiguration would require reinitializing MemoryManager
        // This is a configuration setting for future use
    }
    
    // MARK: - Private Methods
    private func setupSubsystems() async throws {
        print("   📦 Initializing MemoryManager...")
        memoryManager = MemoryManager(device: device)
        subsystems["MemoryManager"] = memoryManager!
        print("      ✅ MemoryManager initialized")
        
        print("   📦 Initializing MetalRenderingEngine...")
        renderingEngine = MetalRenderingEngine(device: device)
        try await renderingEngine?.initialize()
        subsystems["MetalRenderingEngine"] = renderingEngine!
        print("      ✅ MetalRenderingEngine initialized")
        
        // Initialize ray tracing engine (optional - may fail on unsupported devices)
        print("   📦 Initializing MetalRayTracingEngine (optional)...")
        rayTracingEngine = MetalRayTracingEngine(device: device)
        do {
            try await rayTracingEngine?.initialize()
            subsystems["MetalRayTracingEngine"] = rayTracingEngine!
            print("      ✅ MetalRayTracingEngine initialized successfully")
        } catch {
            print("      ⚠️ Ray tracing not supported on this device: \(error)")
            // Ray tracing is optional, continue without it
        }
        
        print("   📦 Initializing Graphics2D...")
        graphics2D = Graphics2D(device: device)
        try await graphics2D?.initialize()
        subsystems["Graphics2D"] = graphics2D!
        print("      ✅ Graphics2D initialized")
        
        print("   📦 Initializing AudioEngine...")
        audioEngine = AudioEngine()
        do {
        try await audioEngine?.initialize()
        subsystems["AudioEngine"] = audioEngine!
            print("      ✅ AudioEngine initialized")
        } catch {
            print("      ⚠️ AudioEngine failed (non-critical): \(error)")
            // Audio is optional, continue without it
        }
        
        print("   📦 Initializing InputManager...")
        inputManager = InputManager()
        try await inputManager?.initialize()
        subsystems["InputManager"] = inputManager!
        print("      ✅ InputManager initialized")
        
        print("   📦 Initializing UnifiedClockSystem...")
        clockSystem = UnifiedClockSystem()
        subsystems["UnifiedClockSystem"] = clockSystem!
        print("      ✅ UnifiedClockSystem initialized")
    }
    
    private func setupSynchronization() async throws {
        guard let clockSystem = clockSystem else { return }
        
        // Add timing callbacks for each subsystem
        clockSystem.addTimingCallback(for: .rendering) { [weak self] time, deltaTime in
            Task { @MainActor [weak self] in
                self?.renderingEngine?.updateTiming(time: time, deltaTime: deltaTime)
            }
        }
        
        clockSystem.addTimingCallback(for: .audio) { [weak self] time, deltaTime in
            Task { @MainActor [weak self] in
                self?.audioEngine?.updateTiming(time: time, deltaTime: deltaTime)
            }
        }
        
        clockSystem.addTimingCallback(for: .input) { [weak self] time, deltaTime in
            Task { @MainActor [weak self] in
                self?.inputManager?.updateTiming(time: time, deltaTime: deltaTime)
            }
        }
        
        // Add global timing callback
        clockSystem.addGlobalTimingCallback { [weak self] time, deltaTime in
            Task { @MainActor [weak self] in
                self?.updateGlobalTiming(time: time, deltaTime: deltaTime)
            }
        }
    }
    
    private func setupPerformanceMonitoring() async throws {
        performanceMonitor = PerformanceMonitor(device: device)
        performanceMonitor?.startMonitoring()
        subsystems["PerformanceMonitor"] = performanceMonitor!
    }
    
    private func startSubsystems() async throws {
        // Start clock system first
        clockSystem?.start()
        
        // Start other subsystems
        try await audioEngine?.start()
        inputManager?.start()
    }
    
    private func stopSubsystems() {
        // Stop clock system first
        clockSystem?.stop()
        
        // Stop audio
        audioEngine?.stop()
        
        // Stop performance monitoring
        performanceMonitor?.stopMonitoring()
        
        // Rendering and input are passive and don't need explicit stop
        // They'll stop automatically when the main loop stops
    }
    
    private func pauseSubsystems() {
        // Pause clock
        clockSystem?.pause()
        
        // Pause audio
        audioEngine?.pause()
        
        // Rendering and input continue to process but at paused timing
        // This allows the UI to remain responsive during pause
    }
    
    private func resumeSubsystems() async throws {
        // Resume clock first
        clockSystem?.resume()
        
        // Resume audio
        audioEngine?.resume()
        
        // Rendering and input automatically resume with the clock
    }
    
    private func startMainLoop() {
        // The main loop is handled by the MTKView delegate
        // This method can be used for additional background processing
    }
    
    private func updateGlobalTiming(time: TimeInterval, deltaTime: TimeInterval) {
        // Update global timing for all subsystems
        lastFrameTime = deltaTime
    }
    
    private func updateSynchronizationQuality() {
        // Calculate synchronization quality based on timing consistency
        let targetFrameTime = 1.0 / 120.0 // 120 FPS target
        let frameTimeError = abs(lastFrameTime - targetFrameTime)
        let maxError = targetFrameTime * 0.1 // 10% tolerance
        
        synchronizationQuality = max(0, min(1, 1.0 - Float(frameTimeError / maxError)))
    }
}

// MARK: - Subsystem Extensions
extension MetalRenderingEngine {
    func updateTiming(time: TimeInterval, deltaTime: TimeInterval) {
        // Update rendering timing
    }
}

extension AudioEngine {
    func updateTiming(time: TimeInterval, deltaTime: TimeInterval) {
        // Update audio timing
    }
    
    func start() async throws {
        // Start audio engine
    }
}

extension InputManager {
    func updateTiming(time: TimeInterval, deltaTime: TimeInterval) {
        // Update input timing
    }
    
    func start() {
        // Start input manager
    }
}
