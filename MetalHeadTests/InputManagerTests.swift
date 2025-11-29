import XCTest
import simd
@testable import MetalHeadEngine

/// Unit tests for InputManager
final class InputManagerTests: XCTestCase {
    
    var inputManager: InputManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        inputManager = InputManager()
    }
    
    override func tearDownWithError() throws {
        inputManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testInputManagerInitialization() async throws {
        // Given
        XCTAssertNotNil(inputManager)
        
        // When
        try await inputManager.initialize()
        
        // Then
        XCTAssertFalse(inputManager.isMouseCaptured)
        XCTAssertEqual(inputManager.mousePosition, SIMD2<Float>(0, 0))
    }
    
    func testInputManagerProperties() {
        // Given & When
        let manager = InputManager()
        
        // Then
        XCTAssertFalse(manager.isMouseCaptured)
        XCTAssertEqual(manager.mousePosition, SIMD2<Float>(0, 0))
        XCTAssertEqual(manager.mouseDelta, SIMD2<Float>(0, 0))
        XCTAssertEqual(manager.scrollDelta, SIMD2<Float>(0, 0))
    }
    
    // MARK: - Mouse Capture Tests
    
    func testMouseCaptureToggle() {
        // Given
        let initialCaptureState = inputManager.isMouseCaptured
        
        // When
        inputManager.toggleMouseCapture()
        
        // Then
        XCTAssertEqual(inputManager.isMouseCaptured, !initialCaptureState)
        
        // When
        inputManager.toggleMouseCapture()
        
        // Then
        XCTAssertEqual(inputManager.isMouseCaptured, initialCaptureState)
    }
    
    func testMouseCapture() {
        // Given
        XCTAssertFalse(inputManager.isMouseCaptured)
        
        // When
        inputManager.captureMouse()
        
        // Then
        XCTAssertTrue(inputManager.isMouseCaptured)
    }
    
    func testMouseRelease() {
        // Given
        inputManager.captureMouse()
        XCTAssertTrue(inputManager.isMouseCaptured)
        
        // When
        inputManager.releaseMouse()
        
        // Then
        XCTAssertFalse(inputManager.isMouseCaptured)
    }
    
    // MARK: - Sensitivity Tests
    
    func testMouseSensitivity() {
        // Given
        let sensitivity: Float = 2.0
        
        // When
        inputManager.setMouseSensitivity(sensitivity)
        
        // Then
        XCTAssertEqual(inputManager.mouseSensitivity, sensitivity)
    }
    
    func testScrollSensitivity() {
        // Given
        let sensitivity: Float = 1.5
        
        // When
        inputManager.setScrollSensitivity(sensitivity)
        
        // Then
        XCTAssertEqual(inputManager.scrollSensitivity, sensitivity)
    }
    
    func testInputSensitivity() {
        // Given
        let sensitivity: Float = 0.8
        
        // When
        inputManager.setInputSensitivity(sensitivity)
        
        // Then
        XCTAssertEqual(inputManager.inputSensitivity, sensitivity)
    }
    
    func testSensitivityClamping() {
        // Given
        let invalidSensitivity: Float = 15.0
        
        // When
        inputManager.setMouseSensitivity(invalidSensitivity)
        
        // Then
        XCTAssertEqual(inputManager.mouseSensitivity, 10.0) // Should be clamped to 10.0
    }
    
    func testNegativeSensitivityClamping() {
        // Given
        let invalidSensitivity: Float = -0.5
        
        // When
        inputManager.setMouseSensitivity(invalidSensitivity)
        
        // Then
        XCTAssertEqual(inputManager.mouseSensitivity, 0.1) // Should be clamped to 0.1
    }
    
    // MARK: - Key Mapping Tests
    
    func testKeyMapping() {
        // Given
        let keyName = "jump"
        let keyCode: UInt16 = 49
        
        // When
        inputManager.setKeyMapping(keyName, to: keyCode)
        
        // Then
        XCTAssertEqual(inputManager.getKeyMapping(keyName), keyCode)
    }
    
    func testKeyMappingRetrieval() {
        // Given
        let keyName = "nonexistent"
        
        // When
        let keyCode = inputManager.getKeyMapping(keyName)
        
        // Then
        XCTAssertNil(keyCode)
    }
    
    // MARK: - Action Binding Tests
    
    func testActionBinding() {
        // Given
        let actionName = "move_forward"
        let keyCodes: [UInt16] = [13, 17] // W and A keys
        
        // When
        inputManager.setActionBinding(actionName, to: keyCodes)
        
        // Then
        XCTAssertEqual(inputManager.getActionBinding(actionName), keyCodes)
    }
    
    func testActionBindingRetrieval() {
        // Given
        let actionName = "nonexistent"
        
        // When
        let keyCodes = inputManager.getActionBinding(actionName)
        
        // Then
        XCTAssertNil(keyCodes)
    }
    
    // MARK: - Key State Tests
    
    func testKeyPressedState() {
        // Given
        let keyCode: UInt16 = 49 // Space key
        
        // When
        let isPressed = inputManager.isKeyPressed(keyCode)
        
        // Then
        XCTAssertFalse(isPressed) // Should not be pressed initially
    }
    
    func testKeyPressedByName() {
        // Given
        let keyName = "jump"
        inputManager.setKeyMapping(keyName, to: 49)
        
        // When
        let isPressed = inputManager.isKeyPressed(keyName)
        
        // Then
        XCTAssertFalse(isPressed) // Should not be pressed initially
    }
    
    func testInvalidKeyPressedByName() {
        // Given
        let keyName = "nonexistent"
        
        // When
        let isPressed = inputManager.isKeyPressed(keyName)
        
        // Then
        XCTAssertFalse(isPressed)
    }
    
    // MARK: - Mouse Button Tests
    
    func testMouseButtonPressed() {
        // Given
        let button = MouseButton.left
        
        // When
        let isPressed = inputManager.isMouseButtonPressed(button)
        
        // Then
        XCTAssertFalse(isPressed) // Should not be pressed initially
    }
    
    func testActionPressed() {
        // Given
        let actionName = "move_forward"
        inputManager.setActionBinding(actionName, to: [13])
        
        // When
        let isPressed = inputManager.isActionPressed(actionName)
        
        // Then
        XCTAssertFalse(isPressed) // Should not be pressed initially
    }
    
    func testInvalidActionPressed() {
        // Given
        let actionName = "nonexistent"
        
        // When
        let isPressed = inputManager.isActionPressed(actionName)
        
        // Then
        XCTAssertFalse(isPressed)
    }
    
    // MARK: - Gamepad Tests
    
    func testGamepadSupport() {
        // Given
        inputManager.setupGamepadSupport()
        
        // When
        let gamepads = inputManager.getConnectedGamepads()
        
        // Then
        XCTAssertNotNil(gamepads)
        XCTAssertTrue(gamepads.isEmpty) // No gamepads connected in test environment
    }
    
    func testGamepadDiscovery() {
        // Given
        inputManager.setupGamepadSupport()
        
        // When & Then - should not throw
        XCTAssertNoThrow(inputManager.stopGamepadDiscovery(), "Stopping gamepad discovery should not throw")
        
        // Verify we can stop multiple times
        XCTAssertNoThrow(inputManager.stopGamepadDiscovery(), "Stopping twice should be handled gracefully")
        
        // Verify we can start again after stopping
        XCTAssertNoThrow(inputManager.startGamepadDiscovery(), "Should be able to start discovery after stopping")
    }
    
    // MARK: - Performance Tests
    
    func testInputProcessingPerformance() async throws {
        // Given
        try await inputManager.initialize()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for _ in 0..<1000 {
            inputManager.isKeyPressed(49)
            inputManager.isMouseButtonPressed(.left)
            inputManager.isActionPressed("move_forward")
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.1, "Input processing should be fast")
    }
}
