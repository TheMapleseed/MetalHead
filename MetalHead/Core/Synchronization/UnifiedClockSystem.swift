import Foundation
import AVFoundation
import CoreAudio
import AudioToolbox
import Combine
import simd
import QuartzCore

/// Unified clock system that synchronizes all multimedia subsystems
@MainActor
public class UnifiedClockSystem: ObservableObject {
    // MARK: - Properties
    @Published public var masterTime: TimeInterval = 0
    @Published public var isRunning: Bool = false
    @Published public var systemLatency: TimeInterval = 0
    @Published public var audioLatency: TimeInterval = 0
    @Published public var renderLatency: TimeInterval = 0
    @Published public var inputLatency: TimeInterval = 0
    
    // Core timing
    private var startTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var frameCount: UInt64 = 0
    private var targetFrameRate: Double = 120.0
    private var frameInterval: TimeInterval = 0
    
    // System time synchronization
    private var systemTimeOffset: TimeInterval = 0
    private var lastSystemTimeCheck: TimeInterval = 0
    private let systemTimeCheckInterval: TimeInterval = 1.0
    
    // Latency compensation
    private var latencyCompensations: [SubsystemType: TimeInterval] = [:]
    private var latencyHistory: [SubsystemType: [TimeInterval]] = [:]
    private let maxLatencyHistorySize = 100
    
    // Subsystem synchronization
    private var subsystemClocks: [SubsystemType: SubsystemClock] = [:]
    private var synchronizationQueue = DispatchQueue(label: "com.metalhead.sync", qos: .userInteractive)
    
    // Timing callbacks
    private var timingCallbacks: [SubsystemType: [TimingCallback]] = [:]
    private var globalCallbacks: [GlobalTimingCallback] = []
    
    // Performance monitoring
    private var performanceMetrics = TimingPerformanceMetrics()
    private var timingDrift: TimeInterval = 0
    private var maxDriftThreshold: TimeInterval = 0.016
    
    // Thread safety
    private let clockLock = NSLock()
    private let callbackLock = NSLock()
    
    // MARK: - Initialization
    public init() {
        setupSystemTimeSynchronization()
        initializeSubsystemClocks()
        setupLatencyCompensation()
    }
    
    // MARK: - Public Interface
    public func start() {
        clockLock.lock()
        defer { clockLock.unlock() }
        
        guard !isRunning else { return }
        
        startTime = CACurrentMediaTime()
        lastUpdateTime = startTime
        frameCount = 0
        frameInterval = 1.0 / targetFrameRate
        
        isRunning = true
        
        for (_, clock) in subsystemClocks {
            clock.start()
        }
        
        startTimingUpdateLoop()
        print("Unified clock system started")
    }
    
    public func stop() {
        clockLock.lock()
        defer { clockLock.unlock() }
        
        guard isRunning else { return }
        
        isRunning = false
        
        for (_, clock) in subsystemClocks {
            clock.stop()
        }
        
        print("Unified clock system stopped")
    }
    
    public func pause() {
        clockLock.lock()
        defer { clockLock.unlock() }
        
        isRunning = false
        
        for (_, clock) in subsystemClocks {
            clock.pause()
        }
    }
    
    public func resume() {
        clockLock.lock()
        defer { clockLock.unlock() }
        
        isRunning = true
        
        for (_, clock) in subsystemClocks {
            clock.resume()
        }
    }
    
    public func getCurrentTime() -> TimeInterval {
        return masterTime
    }
    
    public func getCurrentFrame() -> UInt64 {
        return frameCount
    }
    
    public func getFrameRate() -> Double {
        return 1.0 / frameInterval
    }
    
    public func setTargetFrameRate(_ frameRate: Double) {
        targetFrameRate = frameRate
        frameInterval = 1.0 / frameRate
    }
    
    public func getCompensatedTime(for subsystemType: SubsystemType) -> TimeInterval {
        let compensation = latencyCompensations[subsystemType] ?? 0
        return masterTime + compensation
    }
    
    public func addTimingCallback(for subsystemType: SubsystemType, callback: @escaping TimingCallback) {
        callbackLock.lock()
        defer { callbackLock.unlock() }
        
        if timingCallbacks[subsystemType] == nil {
            timingCallbacks[subsystemType] = []
        }
        timingCallbacks[subsystemType]?.append(callback)
    }
    
    public func addGlobalTimingCallback(_ callback: @escaping GlobalTimingCallback) {
        callbackLock.lock()
        defer { callbackLock.unlock() }
        
        globalCallbacks.append(callback)
    }
    
    public func getPerformanceMetrics() -> TimingPerformanceMetrics {
        return performanceMetrics
    }
    
    // MARK: - Private Methods
    private func setupSystemTimeSynchronization() {
        NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleSystemTimeChange()
            }
        }
        
        // AVAudioSession is not available on macOS
        // On macOS, audio interruptions are handled differently
    }
    
    private func handleSystemTimeChange() async {
        let currentSystemTime = CACurrentMediaTime()
        systemTimeOffset = currentSystemTime - masterTime
        notifySubsystemsOfTimeChange()
    }
    
    private func handleAudioInterruption(_ notification: Notification) {
        // AVAudioSession not available on macOS
        // Handle audio interruption through other mechanisms if needed
    }
    
    private func initializeSubsystemClocks() {
        for subsystemType in SubsystemType.allCases {
            subsystemClocks[subsystemType] = SubsystemClock(
                type: subsystemType,
                masterClock: self
            )
        }
    }
    
    private func setupLatencyCompensation() {
        latencyCompensations[.rendering] = 0.008
        latencyCompensations[.audio] = 0.010
        latencyCompensations[.input] = 0.002
        latencyCompensations[.physics] = 0.005
        
        for subsystemType in SubsystemType.allCases {
            latencyHistory[subsystemType] = []
        }
    }
    
    private func startTimingUpdateLoop() {
        Task { @MainActor [weak self] in
            await self?.timingUpdateLoop()
        }
    }
    
    private func timingUpdateLoop() async {
        while isRunning {
            let currentTime = CACurrentMediaTime()
            let deltaTime = currentTime - lastUpdateTime
            
            masterTime = currentTime - startTime
            frameCount += 1
            
            updatePerformanceMetrics(deltaTime: deltaTime)
            checkTimingDrift()
            updateSubsystemClocks(deltaTime: deltaTime)
            executeTimingCallbacks(deltaTime: deltaTime)
            
            lastUpdateTime = currentTime
            
            let sleepTime = frameInterval - (CACurrentMediaTime() - currentTime)
            if sleepTime > 0 {
                try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
            }
        }
    }
    
    private func updateSubsystemClocks(deltaTime: TimeInterval) {
        for (subsystemType, clock) in subsystemClocks {
            let compensatedTime = getCompensatedTime(for: subsystemType)
            clock.update(compensatedTime: compensatedTime, deltaTime: deltaTime)
        }
    }
    
    private func notifySubsystemsOfTimeChange() {
        for (_, clock) in subsystemClocks {
            clock.handleTimeChange()
        }
    }
    
    private func executeTimingCallbacks(deltaTime: TimeInterval) {
        callbackLock.lock()
        defer { callbackLock.unlock() }
        
        for callback in globalCallbacks {
            callback(masterTime, deltaTime)
        }
        
        for (subsystemType, callbacks) in timingCallbacks {
            let compensatedTime = getCompensatedTime(for: subsystemType)
            for callback in callbacks {
                callback(compensatedTime, deltaTime)
            }
        }
    }
    
    private func updatePerformanceMetrics(deltaTime: CFTimeInterval) {
        performanceMetrics.totalFrames += 1
        performanceMetrics.totalTime += deltaTime
        performanceMetrics.averageFrameTime = performanceMetrics.totalTime / Double(performanceMetrics.totalFrames)
        
        let frameTimeVariance = abs(deltaTime - frameInterval)
        performanceMetrics.frameTimeVariance = (performanceMetrics.frameTimeVariance + frameTimeVariance) / 2.0
        
        performanceMetrics.maxFrameTime = max(performanceMetrics.maxFrameTime, deltaTime)
    }
    
    private func checkTimingDrift() {
        let expectedTime = Double(frameCount) * frameInterval
        timingDrift = abs(masterTime - expectedTime)
        
        if timingDrift > maxDriftThreshold {
            print("Warning: Timing drift detected: \(timingDrift * 1000)ms")
            correctTimingDrift()
        }
    }
    
    private func correctTimingDrift() {
        let expectedFrameTime = 1.0 / targetFrameRate
        let correctionFactor = 1.0 - (timingDrift / expectedFrameTime)
        frameInterval *= correctionFactor
        
        for (_, clock) in subsystemClocks {
            clock.handleTimingCorrection(correctionFactor: correctionFactor)
        }
    }
    
    // MARK: - Cleanup
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Subsystem Clock
public class SubsystemClock {
    public let type: SubsystemType
    private weak var masterClock: UnifiedClockSystem?
    
    private var localTime: TimeInterval = 0
    private var isRunning: Bool = false
    private var lastUpdateTime: TimeInterval = 0
    
    public init(type: SubsystemType, masterClock: UnifiedClockSystem) {
        self.type = type
        self.masterClock = masterClock
    }
    
    public func start() {
        isRunning = true
        localTime = 0
        lastUpdateTime = CACurrentMediaTime()
    }
    
    public func stop() {
        isRunning = false
    }
    
    public func pause() {
        isRunning = false
    }
    
    public func resume() {
        isRunning = true
        lastUpdateTime = CACurrentMediaTime()
    }
    
    public func update(compensatedTime: TimeInterval, deltaTime: TimeInterval) {
        guard isRunning else { return }
        
        localTime = compensatedTime
        lastUpdateTime = CACurrentMediaTime()
    }
    
    public func handleTimeChange() {
        lastUpdateTime = CACurrentMediaTime()
    }
    
    public func handleTimingCorrection(correctionFactor: Double) {
        localTime *= correctionFactor
    }
    
    public func getCurrentTime() -> TimeInterval {
        return localTime
    }
    
    public func getDeltaTime() -> TimeInterval {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        return deltaTime
    }
}

// MARK: - Supporting Types
public enum SubsystemType: CaseIterable {
    case rendering
    case audio
    case input
    case physics
}

public typealias TimingCallback = (TimeInterval, TimeInterval) -> Void
public typealias GlobalTimingCallback = (TimeInterval, TimeInterval) -> Void

public struct TimingPerformanceMetrics {
    public var totalFrames: UInt64 = 0
    public var totalTime: TimeInterval = 0
    public var averageFrameTime: TimeInterval = 0
    public var frameTimeVariance: TimeInterval = 0
    public var maxFrameTime: TimeInterval = 0
    public var timingDrift: TimeInterval = 0
    
    public init() {}
}
