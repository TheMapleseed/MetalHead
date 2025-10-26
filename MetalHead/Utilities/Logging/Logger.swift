import Foundation
import os.log

/// Comprehensive logging system for MetalHead engine
public class Logger {
    
    // MARK: - Singleton
    public static let shared = Logger()
    
    private init() {
        setupLogging()
    }
    
    // MARK: - Log Categories
    private let renderingLog = OSLog(subsystem: "com.metalhead.rendering", category: "Rendering")
    private let audioLog = OSLog(subsystem: "com.metalhead.audio", category: "Audio")
    private let inputLog = OSLog(subsystem: "com.metalhead.input", category: "Input")
    private let memoryLog = OSLog(subsystem: "com.metalhead.memory", category: "Memory")
    private let clockLog = OSLog(subsystem: "com.metalhead.clock", category: "Clock")
    private let performanceLog = OSLog(subsystem: "com.metalhead.performance", category: "Performance")
    private let errorLog = OSLog(subsystem: "com.metalhead.error", category: "Error")
    private let rayTracingLog = OSLog(subsystem: "com.metalhead.raytracing", category: "RayTracing")
    private let geometryLog = OSLog(subsystem: "com.metalhead.geometry", category: "Geometry")
    
    // MARK: - Log Configuration
    public var isVerbose: Bool = false
    public var isDebug: Bool = true
    public var isProduction: Bool = false
    
    // MARK: - Logging Methods
    
    // MARK: Rendering
    public func logRendering(_ message: String, level: LogLevel = .info) {
        log(message, category: renderingLog, level: level)
    }
    
    // MARK: Audio
    public func logAudio(_ message: String, level: LogLevel = .info) {
        log(message, category: audioLog, level: level)
    }
    
    // MARK: Input
    public func logInput(_ message: String, level: LogLevel = .info) {
        log(message, category: inputLog, level: level)
    }
    
    // MARK: Memory
    public func logMemory(_ message: String, level: LogLevel = .info) {
        log(message, category: memoryLog, level: level)
    }
    
    // MARK: Clock
    public func logClock(_ message: String, level: LogLevel = .info) {
        log(message, category: clockLog, level: level)
    }
    
    // MARK: Performance
    public func logPerformance(_ message: String, level: LogLevel = .info) {
        log(message, category: performanceLog, level: level)
    }
    
    // MARK: Error
    public func logError(_ message: String, error: Error? = nil) {
        var fullMessage = message
        if let error = error {
            fullMessage += ": \(error.localizedDescription)"
        }
        log(fullMessage, category: errorLog, level: .error)
    }
    
    // MARK: Ray Tracing
    public func logRayTracing(_ message: String, level: LogLevel = .info) {
        log(message, category: rayTracingLog, level: level)
    }
    
    // MARK: Geometry
    public func logGeometry(_ message: String, level: LogLevel = .info) {
        log(message, category: geometryLog, level: level)
    }
    
    // MARK: Generic
    public func log(_ message: String, category: OSLog, level: LogLevel = .info) {
        guard shouldLog(level: level) else { return }
        
        let osLogLevel: OSLogType
        switch level {
        case .debug:
            osLogLevel = .debug
        case .info:
            osLogLevel = .info
        case .warning:
            osLogLevel = .default
        case .error:
            osLogLevel = .error
        case .fault:
            osLogLevel = .fault
        }
        
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(level.rawValue.uppercased()): \(message)"
        
        os_log("%{public}s", log: category, type: osLogLevel, logMessage)
        
        if isVerbose {
            print(logMessage)
        }
    }
    
    // MARK: - Performance Logging
    
    public func startTimer(label: String) -> CFTimeInterval {
        let startTime = CACurrentMediaTime()
        return startTime
    }
    
    public func endTimer(label: String, startTime: CFTimeInterval) {
        let duration = CACurrentMediaTime() - startTime
        logPerformance("\(label): \(String(format: "%.3f", duration))ms", level: .info)
    }
    
    public func measureTime<T>(_ label: String, _ block: () throws -> T) rethrows -> T {
        let startTime = startTimer(label: label)
        defer {
            endTimer(label: label, startTime: startTime)
        }
        return try block()
    }
    
    // MARK: - Memory Logging
    
    public func logMemoryUsage() {
        let usage = getMemoryUsage()
        logMemory("Current memory: \(formatBytes(usage))", level: .info)
    }
    
    // MARK: - Frame Logging
    
    private var frameCount = 0
    private var lastLogTime: CFTimeInterval = 0
    
    public func logFrame() {
        frameCount += 1
        let currentTime = CACurrentMediaTime()
        
        if currentTime - lastLogTime >= 1.0 {
            logPerformance("FPS: \(frameCount)", level: .info)
            frameCount = 0
            lastLogTime = currentTime
        }
    }
    
    // MARK: - Error Logging with Context
    
    public func logErrorWithContext(_ message: String, context: [String: Any] = [:], error: Error? = nil) {
        var fullMessage = message
        
        if !context.isEmpty {
            fullMessage += "\nContext:"
            for (key, value) in context {
                fullMessage += "\n  \(key): \(value)"
            }
        }
        
        if let error = error {
            fullMessage += "\nError: \(error.localizedDescription)"
            if let nsError = error as NSError? {
                fullMessage += "\nDomain: \(nsError.domain)"
                fullMessage += "\nCode: \(nsError.code)"
            }
        }
        
        logError(fullMessage, error: error)
    }
    
    // MARK: - Batch Logging
    
    public func logBatch(_ messages: [String], category: OSLog, level: LogLevel = .info) {
        for message in messages {
            log(message, category: category, level: level)
        }
    }
    
    // MARK: - Conditional Logging
    
    public func logIf(_ condition: Bool, _ message: String, category: OSLog, level: LogLevel = .info) {
        if condition {
            log(message, category: category, level: level)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupLogging() {
        // Additional setup if needed
    }
    
    private func shouldLog(level: LogLevel) -> Bool {
        if isProduction {
            return level == .error || level == .fault
        }
        
        if !isDebug && level == .debug {
            return false
        }
        
        return true
    }
    
    private func getMemoryUsage() -> UInt64 {
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

// MARK: - Supporting Types

public enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case fault = "FAULT"
}

// MARK: - Extensions

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

extension Logger {
    
    // MARK: - Convenience Methods
    
    public static func rendering(_ message: String, level: LogLevel = .info) {
        shared.logRendering(message, level: level)
    }
    
    public static func audio(_ message: String, level: LogLevel = .info) {
        shared.logAudio(message, level: level)
    }
    
    public static func input(_ message: String, level: LogLevel = .info) {
        shared.logInput(message, level: level)
    }
    
    public static func memory(_ message: String, level: LogLevel = .info) {
        shared.logMemory(message, level: level)
    }
    
    public static func clock(_ message: String, level: LogLevel = .info) {
        shared.logClock(message, level: level)
    }
    
    public static func performance(_ message: String, level: LogLevel = .info) {
        shared.logPerformance(message, level: level)
    }
    
    public static func error(_ message: String, error: Error? = nil) {
        shared.logError(message, error: error)
    }
    
    public static func rayTracing(_ message: String, level: LogLevel = .info) {
        shared.logRayTracing(message, level: level)
    }
    
    public static func geometry(_ message: String, level: LogLevel = .info) {
        shared.logGeometry(message, level: level)
    }
}
