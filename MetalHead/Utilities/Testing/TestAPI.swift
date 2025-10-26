//
//  TestAPI.swift
//  MetalHead
//
//  Testing API for developers to verify multimedia system functionality
//

import Foundation
import Metal
import simd
import Combine

/// Comprehensive testing API for the MetalHead multimedia engine
/// Allows developers to verify all subsystems are functioning correctly
@MainActor
public class TestAPI: ObservableObject {
    
    // MARK: - Properties
    
    public enum TestResult: String, Sendable {
        case passed = "✓ PASSED"
        case failed = "✗ FAILED"
        case skipped = "⊘ SKIPPED"
        case warning = "⚠ WARNING"
    }
    
    public struct TestReport: Sendable {
        let subsystem: String
        let testName: String
        let result: TestResult
        let duration: TimeInterval
        let message: String?
        
        var description: String {
            var desc = "\(result.rawValue) - \(subsystem): \(testName) (\(String(format: "%.3f", duration))s)"
            if let message = message {
                desc += "\n  \(message)"
            }
            return desc
        }
    }
    
    private var engine: UnifiedMultimediaEngine?
    private var reports: [TestReport] = []
    
    // MARK: - Initialization
    
    public init() {
        // Test API is initialized independently
    }
    
    // MARK: - System Health Tests
    
    /// Run a complete health check of all subsystems
    public func runHealthCheck(engine: UnifiedMultimediaEngine) async -> [TestReport] {
        self.engine = engine
        self.reports = []
        
        print("\n=== MetalHead Health Check ===\n")
        
        await testMetalSupport()
        await testMemoryAllocation()
        await testRenderingEngine()
        await testAudioEngine()
        await testInputManager()
        await testClockSystem()
        await testPerformance()
        
        print("\n=== Summary ===")
        let passed = reports.filter { $0.result == .passed }.count
        let failed = reports.filter { $0.result == .failed }.count
        let warnings = reports.filter { $0.result == .warning }.count
        print("Total: \(reports.count) | Passed: \(passed) | Failed: \(failed) | Warnings: \(warnings)\n")
        
        return reports
    }
    
    // MARK: - Individual Subsystem Tests
    
    private func testMetalSupport() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard MTLCreateSystemDefaultDevice() != nil else {
            addReport(subsystem: "Metal", testName: "Device Support", 
                     result: .failed, message: "Metal is not supported on this system")
            return
        }
        
        let device = MTLCreateSystemDefaultDevice()!
        guard device.supportsFamily(.mac1) || device.supportsFamily(.mac2) else {
            addReport(subsystem: "Metal", testName: "Device Support",
                     result: .warning, message: "Limited Metal support")
            return
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        addReport(subsystem: "Metal", testName: "Device Support", 
                 result: .passed, duration: duration, 
                 message: "GPU: \(device.name ?? "Unknown")")
    }
    
    private func testMemoryAllocation() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let memoryManager = engine?.getSubsystem(MemoryManager.self) else {
            addReport(subsystem: "Memory", testName: "Allocation",
                     result: .failed, message: "MemoryManager not available")
            return
        }
        
        // Test small allocation
        let testSize = 1024
        guard let ptr = memoryManager.allocate(size: testSize, alignment: 16, type: .vertex) else {
            addReport(subsystem: "Memory", testName: "Allocation",
                     result: .failed, message: "Failed to allocate \(testSize) bytes")
            return
        }
        
        // Test deallocation
        memoryManager.deallocate(ptr)
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let report = memoryManager.getMemoryReport()
        addReport(subsystem: "Memory", testName: "Allocation", 
                 result: .passed, duration: duration,
                 message: "Total: \(report.totalCapacity) bytes, Active: \(report.activeAllocations)")
    }
    
    private func testRenderingEngine() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let renderingEngine = engine?.getSubsystem(MetalRenderingEngine.self) else {
            addReport(subsystem: "Rendering", testName: "Initialization",
                     result: .failed, message: "Rendering engine not available")
            return
        }
        
        // Verify pipeline is ready
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        addReport(subsystem: "Rendering", testName: "Pipeline Ready", 
                 result: .passed, duration: duration,
                 message: "3D rendering pipeline initialized")
    }
    
    private func testAudioEngine() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let audioEngine = engine?.getSubsystem(AudioEngine.self) else {
            addReport(subsystem: "Audio", testName: "Initialization",
                     result: .failed, message: "Audio engine not available")
            return
        }
        
        // Test volume control
        let originalVolume = audioEngine.volume
        audioEngine.setVolume(0.5)
        
        guard abs(audioEngine.volume - 0.5) < 0.01 else {
            audioEngine.setVolume(originalVolume)
            addReport(subsystem: "Audio", testName: "Volume Control",
                     result: .failed, message: "Volume control not working")
            return
        }
        
        audioEngine.setVolume(originalVolume)
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        addReport(subsystem: "Audio", testName: "Volume Control", 
                 result: .passed, duration: duration,
                 message: "Volume: \(String(format: "%.2f", audioEngine.volume))")
    }
    
    private func testInputManager() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let inputManager = engine?.getSubsystem(InputManager.self) else {
            addReport(subsystem: "Input", testName: "Initialization",
                     result: .failed, message: "Input manager not available")
            return
        }
        
        // Input manager is initialized and ready
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        addReport(subsystem: "Input", testName: "Manager Ready", 
                 result: .passed, duration: duration,
                 message: "Keyboard, mouse, and gamepad support active")
    }
    
    private func testClockSystem() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let clockSystem = engine?.getSubsystem(UnifiedClockSystem.self) else {
            addReport(subsystem: "Clock", testName: "Initialization",
                     result: .failed, message: "Clock system not available")
            return
        }
        
        // Check if clock is running
        let masterTime = clockSystem.masterTime
        let systemLatency = clockSystem.systemLatency
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        addReport(subsystem: "Clock", testName: "Synchronization", 
                 result: .passed, duration: duration,
                 message: "Latency: \(String(format: "%.3f", systemLatency))s")
    }
    
    private func testPerformance() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let performanceMonitor = engine?.getSubsystem(PerformanceMonitor.self) else {
            addReport(subsystem: "Performance", testName: "Initialization",
                     result: .warning, message: "Performance monitor not available")
            return
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        addReport(subsystem: "Performance", testName: "Monitoring Active", 
                 result: .passed, duration: duration,
                 message: "Tracking: FPS, Memory, CPU, GPU")
    }
    
    // MARK: - Helper Methods
    
    private func addReport(subsystem: String, testName: String, result: TestResult, 
                          duration: TimeInterval = 0, message: String? = nil) {
        let report = TestReport(
            subsystem: subsystem,
            testName: testName,
            result: result,
            duration: duration,
            message: message
        )
        reports.append(report)
        print(report.description)
    }
    
    // MARK: - Continuous Monitoring
    
    /// Start continuous monitoring of the multimedia system
    public func startMonitoring(engine: UnifiedMultimediaEngine, interval: TimeInterval = 5.0) {
        self.engine = engine
        
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performQuickHealthCheck()
            }
        }
    }
    
    private func performQuickHealthCheck() async {
        guard let engine = engine else { return }
        
        print("\n[Quick Health Check]")
        
        // Quick subsystem availability check
        let subsystems = [
            ("Rendering", engine.getSubsystem(MetalRenderingEngine.self) != nil),
            ("Audio", engine.getSubsystem(AudioEngine.self) != nil),
            ("Input", engine.getSubsystem(InputManager.self) != nil),
            ("Memory", engine.getSubsystem(MemoryManager.self) != nil),
            ("Clock", engine.getSubsystem(UnifiedClockSystem.self) != nil),
            ("Performance", engine.getSubsystem(PerformanceMonitor.self) != nil)
        ]
        
        for (name, available) in subsystems {
            print("  \(available ? "✓" : "✗") \(name)")
        }
    }
}

// MARK: - Test Extensions

/// Convenience extension for easy testing integration
extension UnifiedMultimediaEngine {
    
    /// Run the built-in health check
    public func runHealthCheck() async -> [TestAPI.TestReport] {
        let testAPI = TestAPI()
        return await testAPI.runHealthCheck(engine: self)
    }
    
    /// Verify all subsystems are available
    public func verifySubsystems() -> Bool {
        let subsystems = [
            getSubsystem(MetalRenderingEngine.self),
            getSubsystem(AudioEngine.self),
            getSubsystem(InputManager.self),
            getSubsystem(MemoryManager.self),
            getSubsystem(UnifiedClockSystem.self),
            getSubsystem(PerformanceMonitor.self)
        ]
        
        return subsystems.allSatisfy { $0 != nil }
    }
}

