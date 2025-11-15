import Foundation
import Metal
import simd

/// Comprehensive error handling and validation system
@MainActor
public class ErrorHandler: ObservableObject {
    // MARK: - Properties
    @Published public var lastError: EngineError?
    @Published public var errorCount: Int = 0
    @Published public var warningCount: Int = 0
    
    private var errorHistory: [EngineError] = []
    private let maxErrorHistory = 100
    private var errorCallbacks: [(EngineError) -> Void] = []
    
    // MARK: - Singleton
    public static let shared = ErrorHandler()
    
    private init() {}
    
    // MARK: - Error Handling
    
    public func handleError(_ error: EngineError) {
        lastError = error
        errorCount += 1
        
        // Add to history
        errorHistory.append(error)
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeFirst()
        }
        
        // Log error
        logError(error)
        
        // Notify callbacks
        for callback in errorCallbacks {
            callback(error)
        }
        
        // Handle critical errors
        if case .critical = error.severity {
            handleCriticalError(error)
        }
    }
    
    public func handleWarning(_ warning: EngineWarning) {
        warningCount += 1
        logWarning(warning)
    }
    
    public func addErrorCallback(_ callback: @escaping (EngineError) -> Void) {
        errorCallbacks.append(callback)
    }
    
    public func clearErrors() {
        lastError = nil
        errorCount = 0
        warningCount = 0
        errorHistory.removeAll()
    }
    
    // MARK: - Validation
    
    public func validateDevice(_ device: MTLDevice?) -> Bool {
        guard let device = device else {
            handleError(EngineError(
                type: .deviceError,
                message: "Metal device is not available",
                severity: .critical,
                context: ["device": "nil"]
            ))
            return false
        }
        
        // Check device capabilities
        if !device.supportsFamily(.apple7) {
            handleWarning(EngineWarning(
                type: .deviceCapability,
                message: "Device does not support Apple7 family",
                context: ["device": device.name]
            ))
        }
        
        return true
    }
    
    public func validateMemoryAllocation(size: Int, alignment: Int) -> Bool {
        guard size > 0 else {
            handleError(EngineError(
                type: .memoryError,
                message: "Invalid memory allocation size",
                severity: .error,
                context: ["size": String(size)]
            ))
            return false
        }
        
        guard alignment > 0 && alignment.isPowerOfTwo else {
            handleError(EngineError(
                type: .memoryError,
                message: "Invalid memory alignment",
                severity: .error,
                context: ["alignment": String(alignment)]
            ))
            return false
        }
        
        return true
    }
    
    public func validateFrameRate(_ frameRate: Double) -> Bool {
        guard frameRate > 0 && frameRate <= 240 else {
            handleError(EngineError(
                type: .performanceError,
                message: "Invalid frame rate",
                severity: .warning,
                context: ["frameRate": String(frameRate)]
            ))
            return false
        }
        
        return true
    }
    
    public func validateLatency(_ latency: TimeInterval) -> Bool {
        guard latency >= 0 && latency <= 1.0 else {
            handleError(EngineError(
                type: .performanceError,
                message: "Invalid latency value",
                severity: .warning,
                context: ["latency": String(latency)]
            ))
            return false
        }
        
        return true
    }
    
    public func validatePosition(_ position: SIMD3<Float>) -> Bool {
        guard position.x.isFinite && position.y.isFinite && position.z.isFinite else {
            handleError(EngineError(
                type: .validationError,
                message: "Invalid position values",
                severity: .error,
                context: ["position": String(describing: position)]
            ))
            return false
        }
        
        return true
    }
    
    public func validateColor(_ color: SIMD4<Float>) -> Bool {
        guard color.x >= 0 && color.x <= 1 &&
              color.y >= 0 && color.y <= 1 &&
              color.z >= 0 && color.z <= 1 &&
              color.w >= 0 && color.w <= 1 else {
            handleError(EngineError(
                type: .validationError,
                message: "Invalid color values",
                severity: .warning,
                context: ["color": String(describing: color)]
            ))
            return false
        }
        
        return true
    }
    
    // MARK: - Private Methods
    
    private func logError(_ error: EngineError) {
        let timestamp = DateFormatter.iso8601.string(from: Date())
        let logMessage = "[\(timestamp)] ERROR [\(error.severity)] \(error.type.rawValue): \(error.message)"
        
        print(logMessage)
        
        if let context = error.context {
            for (key, value) in context {
                print("  \(key): \(value)")
            }
        }
    }
    
    private func logWarning(_ warning: EngineWarning) {
        let timestamp = DateFormatter.iso8601.string(from: Date())
        let logMessage = "[\(timestamp)] WARNING [\(warning.type.rawValue)]: \(warning.message)"
        
        print(logMessage)
        
        if let context = warning.context {
            for (key, value) in context {
                print("  \(key): \(value)")
            }
        }
    }
    
    private func handleCriticalError(_ error: EngineError) {
        // Handle critical errors that require immediate attention
        switch error.type {
        case .deviceError:
            // Try to recover by recreating the device
            break
        case .memoryError:
            // Try to free memory or reduce allocation
            break
        case .renderingError:
            // Try to reset the rendering pipeline
            break
        case .audioError:
            // Try to reset the audio engine
            break
        case .inputError:
            // Try to reset the input manager
            break
        case .synchronizationError:
            // Try to reset the clock system
            break
        case .performanceError:
            // Try to reduce performance requirements
            break
        case .validationError:
            // Log and continue
            break
        }
    }
}

// MARK: - Error Types

public struct EngineError: Error, Equatable, Sendable {
    public let type: ErrorType
    public let message: String
    public let severity: ErrorSeverity
    public let context: [String: String]?
    public let timestamp: Date
    
    public init(type: ErrorType, message: String, severity: ErrorSeverity, context: [String: String]? = nil) {
        self.type = type
        self.message = message
        self.severity = severity
        self.context = context
        self.timestamp = Date()
    }
}

public struct EngineWarning: Error, Equatable, Sendable {
    public let type: WarningType
    public let message: String
    public let context: [String: String]?
    public let timestamp: Date
    
    public init(type: WarningType, message: String, context: [String: String]? = nil) {
        self.type = type
        self.message = message
        self.context = context
        self.timestamp = Date()
    }
}

public enum ErrorType: String, CaseIterable, Sendable {
    case deviceError = "DeviceError"
    case memoryError = "MemoryError"
    case renderingError = "RenderingError"
    case audioError = "AudioError"
    case inputError = "InputError"
    case synchronizationError = "SynchronizationError"
    case performanceError = "PerformanceError"
    case validationError = "ValidationError"
}

public enum WarningType: String, CaseIterable, Sendable {
    case deviceCapability = "DeviceCapability"
    case performance = "Performance"
    case memory = "Memory"
    case validation = "Validation"
    case deprecated = "Deprecated"
}

public enum ErrorSeverity: String, CaseIterable, Sendable {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
}

// MARK: - Extensions

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

extension Int {
    var isPowerOfTwo: Bool {
        return self > 0 && (self & (self - 1)) == 0
    }
}

// MARK: - Error Recovery

public class ErrorRecovery {
    public static func recoverFromDeviceError() -> Bool {
        // Attempt to recover from device errors
        guard MTLCreateSystemDefaultDevice() != nil else {
            return false
        }
        
        // Validate device capabilities
        // Note: This is a synchronous context calling a main actor method
        // In production, this should be handled differently or made async
        return true
    }
    
    public static func recoverFromMemoryError() -> Bool {
        // Attempt to recover from memory errors
        // This would typically involve garbage collection or memory compaction
        return true
    }
    
    public static func recoverFromRenderingError() -> Bool {
        // Attempt to recover from rendering errors
        // This would typically involve resetting the rendering pipeline
        return true
    }
    
    public static func recoverFromAudioError() -> Bool {
        // Attempt to recover from audio errors
        // This would typically involve resetting the audio engine
        return true
    }
    
    public static func recoverFromInputError() -> Bool {
        // Attempt to recover from input errors
        // This would typically involve resetting the input manager
        return true
    }
    
    public static func recoverFromSynchronizationError() -> Bool {
        // Attempt to recover from synchronization errors
        // This would typically involve resetting the clock system
        return true
    }
}
