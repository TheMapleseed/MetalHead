//
//  TestAPITests.swift
//  MetalHeadTests
//
//  Comprehensive tests for the Testing API
//

import XCTest
import Metal
@testable import MetalHeadEngine

final class TestAPITests: XCTestCase {
    
    var engine: UnifiedMultimediaEngine!
    var testAPI: TestAPI!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw NSError(domain: "Test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Metal not available"])
        }
        
        engine = UnifiedMultimediaEngine()
        testAPI = TestAPI()
    }
    
    override func tearDownWithError() throws {
        engine = nil
        testAPI = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Health Check Tests
    
    func testHealthCheck() async throws {
        // When
        let reports = await testAPI.runHealthCheck(engine: engine)
        
        // Then
        XCTAssertFalse(reports.isEmpty, "Health check should return reports")
        
        let passedTests = reports.filter { $0.result == .passed }
        XCTAssertGreaterThan(passedTests.count, 0, "At least some tests should pass")
        
        // Log results
        for report in reports {
            print("\n" + report.description)
        }
    }
    
    func testSubsystemVerification() {
        // When
        let allAvailable = engine.verifySubsystems()
        
        // Then
        XCTAssertTrue(allAvailable, "All subsystems should be available after initialization")
    }
    
    // MARK: - Individual Component Tests
    
    func testMetalSupportCheck() async {
        // When
        let device = MTLCreateSystemDefaultDevice()
        
        // Then
        XCTAssertNotNil(device, "Metal device should be available")
        
        if let device = device {
            let supported = device.supportsFamily(.mac1) || device.supportsFamily(.mac2)
            XCTAssertTrue(supported, "Device should support Metal")
        }
    }
    
    func testMemoryAllocationFlow() async {
        // Given
        guard let memoryManager = engine.getSubsystem(MemoryManager.self) else {
            XCTFail("Memory manager should be available")
            return
        }
        
        // When
        let ptr = memoryManager.allocate(size: 4096, alignment: 16, type: .vertex)
        
        // Then
        XCTAssertNotNil(ptr, "Memory allocation should succeed")
        
        // Cleanup
        if let ptr = ptr {
            memoryManager.deallocate(ptr)
        }
    }
    
    // MARK: - Performance Tests
    
    func testHealthCheckPerformance() async {
        measure {
            Task {
                let reports = await testAPI.runHealthCheck(engine: engine)
                XCTAssertFalse(reports.isEmpty)
            }
        }
    }
}

