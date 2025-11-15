import Foundation
import Metal
import simd
import QuartzCore

/// Performance monitoring and optimization utilities
@MainActor
public class PerformanceMonitor: ObservableObject {
    // MARK: - Properties
    @Published public var fps: Double = 0
    @Published public var frameTime: TimeInterval = 0
    @Published public var memoryUsage: UInt64 = 0
    @Published public var gpuUtilization: Float = 0
    @Published public var cpuUtilization: Float = 0
    
    // Performance tracking
    private var frameCount: UInt64 = 0
    private var lastFPSTime: CFTimeInterval = 0
    private var frameTimes: [TimeInterval] = []
    private let maxFrameTimeHistory = 60
    
    // System monitoring
    private var processInfo: ProcessInfo
    private var lastCPUUsage: CFTimeInterval = 0
    private var lastSystemTime: CFTimeInterval = 0
    
    // Metal performance
    private let device: MTLDevice
    private var commandQueue: MTLCommandQueue?
    
    // Monitoring timer
    private var monitoringTimer: Timer?
    private let monitoringInterval: TimeInterval = 1.0 / 60.0 // 60 FPS monitoring
    
    // MARK: - Initialization
    public init(device: MTLDevice) {
        self.device = device
        self.processInfo = ProcessInfo.processInfo
        
        if let commandQueue = device.makeCommandQueue() {
            self.commandQueue = commandQueue
        }
    }
    
    // MARK: - Public Interface
    public func startMonitoring() {
        guard monitoringTimer == nil else { return }
        
        // Timer callback must be @MainActor to access @MainActor properties
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.updatePerformanceMetrics()
            }
        }
        
        print("Performance monitoring started")
    }
    
    public func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        print("Performance monitoring stopped")
    }
    
    public func recordFrameTime(_ frameTime: TimeInterval) {
        frameCount += 1
        lastFPSTime += frameTime
        
        // Update frame time history
        frameTimes.append(frameTime)
        if frameTimes.count > maxFrameTimeHistory {
            frameTimes.removeFirst()
        }
        
        // Update FPS
        if lastFPSTime >= 1.0 {
            fps = Double(frameCount) / lastFPSTime
            frameCount = 0
            lastFPSTime = 0
        }
        
        // Update average frame time
        self.frameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
    }
    
    public func getPerformanceReport() -> PerformanceReport {
        return PerformanceReport(
            fps: fps,
            frameTime: frameTime,
            memoryUsage: memoryUsage,
            gpuUtilization: gpuUtilization,
            cpuUtilization: cpuUtilization,
            frameTimeHistory: frameTimes,
            timestamp: CACurrentMediaTime()
        )
    }
    
    public func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return info.resident_size
        }
        
        return 0
    }
    
    public func getCPUUsage() -> Float {
        let currentTime = CACurrentMediaTime()
        let currentSystemTime = processInfo.systemUptime
        
        if lastCPUUsage == 0 {
            lastCPUUsage = currentTime
            lastSystemTime = currentSystemTime
            return 0
        }
        
        let timeDelta = currentTime - lastCPUUsage
        let systemTimeDelta = currentSystemTime - lastSystemTime
        
        let cpuUsage = Float(1.0 - (systemTimeDelta / timeDelta))
        
        lastCPUUsage = currentTime
        lastSystemTime = currentSystemTime
        
        return max(0, min(1, cpuUsage))
    }
    
    public func getGPUUtilization() -> Float {
        // This is a simplified implementation
        // In a real implementation, you would use Metal Performance Shaders
        // or other GPU monitoring tools
        return 0.5 // Placeholder
    }
    
    // MARK: - Private Methods
    private func updatePerformanceMetrics() async {
        memoryUsage = getMemoryUsage()
        cpuUtilization = getCPUUsage()
        gpuUtilization = getGPUUtilization()
    }
}

// MARK: - Performance Report
public struct PerformanceReport: Sendable {
    public let fps: Double
    public let frameTime: TimeInterval
    public let memoryUsage: UInt64
    public let gpuUtilization: Float
    public let cpuUtilization: Float
    public let frameTimeHistory: [TimeInterval]
    public let timestamp: CFTimeInterval
    
    public init(fps: Double, frameTime: TimeInterval, memoryUsage: UInt64, gpuUtilization: Float, cpuUtilization: Float, frameTimeHistory: [TimeInterval], timestamp: CFTimeInterval) {
        self.fps = fps
        self.frameTime = frameTime
        self.memoryUsage = memoryUsage
        self.gpuUtilization = gpuUtilization
        self.cpuUtilization = cpuUtilization
        self.frameTimeHistory = frameTimeHistory
        self.timestamp = timestamp
    }
    
    public var formattedMemoryUsage: String {
        return formatBytes(memoryUsage)
    }
    
    public var averageFrameTime: TimeInterval {
        guard !frameTimeHistory.isEmpty else { return 0 }
        return frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
    }
    
    public var minFrameTime: TimeInterval {
        return frameTimeHistory.min() ?? 0
    }
    
    public var maxFrameTime: TimeInterval {
        return frameTimeHistory.max() ?? 0
    }
    
    public var frameTimeVariance: TimeInterval {
        guard !frameTimeHistory.isEmpty else { return 0 }
        let average = averageFrameTime
        let squaredDiffs = frameTimeHistory.map { pow($0 - average, 2) }
        return squaredDiffs.reduce(0, +) / Double(frameTimeHistory.count)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", size, units[unitIndex])
    }
}

// MARK: - Performance Utilities
public struct PerformanceUtils {
    /// Measure execution time of a block
    public static func measureTime<T>(_ block: () throws -> T) rethrows -> (result: T, time: TimeInterval) {
        let startTime = CACurrentMediaTime()
        let result = try block()
        let endTime = CACurrentMediaTime()
        return (result, endTime - startTime)
    }
    
    /// Measure execution time of an async block
    public static func measureTime<T>(_ block: () async throws -> T) async rethrows -> (result: T, time: TimeInterval) {
        let startTime = CACurrentMediaTime()
        let result = try await block()
        let endTime = CACurrentMediaTime()
        return (result, endTime - startTime)
    }
    
    /// Create a performance timer
    public static func createTimer() -> PerformanceTimer {
        return PerformanceTimer()
    }
    
    /// Benchmark a function multiple times
    public static func benchmark<T>(iterations: Int, _ block: () throws -> T) rethrows -> BenchmarkResult {
        var times: [TimeInterval] = []
        
        for _ in 0..<iterations {
            let (_, time) = try measureTime(block)
            times.append(time)
        }
        
        return BenchmarkResult(times: times)
    }
}

// MARK: - Performance Timer
public class PerformanceTimer {
    private var startTime: CFTimeInterval = 0
    private var isRunning: Bool = false
    
    public init() {}
    
    public func start() {
        startTime = CACurrentMediaTime()
        isRunning = true
    }
    
    public func stop() -> TimeInterval {
        guard isRunning else { return 0 }
        isRunning = false
        return CACurrentMediaTime() - startTime
    }
    
    public func lap() -> TimeInterval {
        guard isRunning else { return 0 }
        let currentTime = CACurrentMediaTime()
        let lapTime = currentTime - startTime
        startTime = currentTime
        return lapTime
    }
    
    public var elapsed: TimeInterval {
        guard isRunning else { return 0 }
        return CACurrentMediaTime() - startTime
    }
}

// MARK: - Benchmark Result
public struct BenchmarkResult: Sendable {
    public let times: [TimeInterval]
    
    public init(times: [TimeInterval]) {
        self.times = times
    }
    
    public var average: TimeInterval {
        guard !times.isEmpty else { return 0 }
        return times.reduce(0, +) / Double(times.count)
    }
    
    public var min: TimeInterval {
        return times.min() ?? 0
    }
    
    public var max: TimeInterval {
        return times.max() ?? 0
    }
    
    public var median: TimeInterval {
        guard !times.isEmpty else { return 0 }
        let sortedTimes = times.sorted()
        let count = sortedTimes.count
        
        if count % 2 == 0 {
            return (sortedTimes[count / 2 - 1] + sortedTimes[count / 2]) / 2
        } else {
            return sortedTimes[count / 2]
        }
    }
    
    public var standardDeviation: TimeInterval {
        guard !times.isEmpty else { return 0 }
        let average = self.average
        let squaredDiffs = times.map { pow($0 - average, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(times.count)
        return sqrt(variance)
    }
    
    public var formatted: String {
        return """
        Benchmark Results:
        - Average: \(average.formatted)
        - Min: \(min.formatted)
        - Max: \(max.formatted)
        - Median: \(median.formatted)
        - Std Dev: \(standardDeviation.formatted)
        - Samples: \(times.count)
        """
    }
}
