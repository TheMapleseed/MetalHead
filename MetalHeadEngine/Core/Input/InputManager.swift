import AppKit
import Foundation
import Combine
import simd

/// Core input manager for keyboard, mouse, and gamepad handling
@MainActor
public class InputManager: ObservableObject {
    // MARK: - Properties
    @Published public var isMouseCaptured: Bool = false
    @Published public var mousePosition: SIMD2<Float> = SIMD2<Float>(0, 0)
    @Published public var mouseDelta: SIMD2<Float> = SIMD2<Float>(0, 0)
    @Published public var scrollDelta: SIMD2<Float> = SIMD2<Float>(0, 0)
    
    // Publishers for input events
    public let keyboardPublisher = PassthroughSubject<UInt16, Never>()
    public let mousePublisher = PassthroughSubject<MouseEvent, Never>()
    public let gamepadPublisher = PassthroughSubject<GamepadEvent, Never>()
    
    // Input state tracking
    private var keyStates: Set<UInt16> = []
    private var mouseButtonStates: Set<MouseButton> = []
    private var lastMousePosition: SIMD2<Float> = SIMD2<Float>(0, 0)
    
    // Input configuration
    private var inputSensitivity: Float = 1.0
    private var mouseSensitivity: Float = 1.0
    private var scrollSensitivity: Float = 1.0
    
    // Event monitoring
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var scrollMonitor: Any?
    private var gamepadMonitor: Any?
    
    // Input mapping
    private var keyMappings: [String: UInt16] = [:]
    private var actionBindings: [String: [UInt16]] = [:]
    
    // MARK: - Initialization
    public init() {
        setupDefaultKeyMappings()
    }
    
    // MARK: - Public Interface
    public func initialize() async throws {
        try await setupInputMonitoring()
        print("Input Manager initialized successfully")
    }
    
    public func isKeyPressed(_ keyCode: UInt16) -> Bool {
        return keyStates.contains(keyCode)
    }
    
    public func isKeyPressed(_ keyName: String) -> Bool {
        guard let keyCode = keyMappings[keyName] else { return false }
        return isKeyPressed(keyCode)
    }
    
    public func isMouseButtonPressed(_ button: MouseButton) -> Bool {
        return mouseButtonStates.contains(button)
    }
    
    public func isActionPressed(_ actionName: String) -> Bool {
        guard let keyCodes = actionBindings[actionName] else { return false }
        return keyCodes.contains { isKeyPressed($0) }
    }
    
    public func toggleMouseCapture() {
        if isMouseCaptured {
            releaseMouse()
        } else {
            captureMouse()
        }
    }
    
    public func captureMouse() {
        isMouseCaptured = true
        CGDisplayHideCursor(CGMainDisplayID())
        CGAssociateMouseAndMouseCursorPosition(0)
    }
    
    public func releaseMouse() {
        isMouseCaptured = false
        CGDisplayShowCursor(CGMainDisplayID())
        CGAssociateMouseAndMouseCursorPosition(1)
    }
    
    public func setMouseSensitivity(_ sensitivity: Float) {
        mouseSensitivity = max(0.1, min(10.0, sensitivity))
    }
    
    public func setScrollSensitivity(_ sensitivity: Float) {
        scrollSensitivity = max(0.1, min(10.0, sensitivity))
    }
    
    public func setInputSensitivity(_ sensitivity: Float) {
        inputSensitivity = max(0.1, min(10.0, sensitivity))
    }
    
    public func setKeyMapping(_ keyName: String, to keyCode: UInt16) {
        keyMappings[keyName] = keyCode
    }
    
    public func setActionBinding(_ actionName: String, to keyCodes: [UInt16]) {
        actionBindings[actionName] = keyCodes
    }
    
    public func getKeyMapping(_ keyName: String) -> UInt16? {
        return keyMappings[keyName]
    }
    
    public func getActionBinding(_ actionName: String) -> [UInt16]? {
        return actionBindings[actionName]
    }
    
    // MARK: - Private Methods
    private func setupDefaultKeyMappings() {
        keyMappings["forward"] = 13
        keyMappings["backward"] = 1
        keyMappings["left"] = 0
        keyMappings["right"] = 2
        keyMappings["up"] = 12
        keyMappings["down"] = 14
        keyMappings["jump"] = 49
        keyMappings["crouch"] = 6
        keyMappings["run"] = 15
        keyMappings["interact"] = 35
        keyMappings["menu"] = 53
        keyMappings["inventory"] = 18
        keyMappings["map"] = 46
        keyMappings["camera_reset"] = 8
        keyMappings["camera_lock"] = 37
        
        actionBindings["move_forward"] = [keyMappings["forward"]!]
        actionBindings["move_backward"] = [keyMappings["backward"]!]
        actionBindings["move_left"] = [keyMappings["left"]!]
        actionBindings["move_right"] = [keyMappings["right"]!]
        actionBindings["move_up"] = [keyMappings["up"]!]
        actionBindings["move_down"] = [keyMappings["down"]!]
        actionBindings["jump"] = [keyMappings["jump"]!]
        actionBindings["crouch"] = [keyMappings["crouch"]!]
        actionBindings["run"] = [keyMappings["run"]!]
        actionBindings["interact"] = [keyMappings["interact"]!]
    }
    
    private func setupInputMonitoring() async throws {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handleKeyboardEvent(event)
            return event
        }
        
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp]) { [weak self] event in
            self?.handleMouseEvent(event)
            return event
        }
        
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.handleScrollEvent(event)
            return event
        }
        
        setupGamepadMonitoring()
    }
    
    private func setupGamepadMonitoring() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            nonisolated(unsafe) let notif = notification
            Task { @MainActor in
                await self?.handleGamepadConnection(notif)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            nonisolated(unsafe) let notif = notification
            Task { @MainActor in
                await self?.handleGamepadDisconnection(notif)
            }
        }
    }
    
    private func handleKeyboardEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        let isKeyDown = event.type == .keyDown
        
        if isKeyDown {
            keyStates.insert(keyCode)
            keyboardPublisher.send(keyCode)
        } else {
            keyStates.remove(keyCode)
        }
        
        handleKeyCombinations(event)
    }
    
    private func handleMouseEvent(_ event: NSEvent) {
        let currentPosition = SIMD2<Float>(Float(event.locationInWindow.x), Float(event.locationInWindow.y))
        
        if isMouseCaptured {
            mouseDelta = currentPosition - lastMousePosition
        }
        
        mousePosition = currentPosition
        lastMousePosition = currentPosition
        
        let mouseEvent = MouseEvent(
            type: getMouseEventType(event),
            position: currentPosition,
            button: getMouseButton(event),
            clickCount: Int(event.clickCount)
        )
        
        mousePublisher.send(mouseEvent)
        updateMouseButtonStates(event)
    }
    
    private func handleScrollEvent(_ event: NSEvent) {
        let scrollDelta = SIMD2<Float>(
            Float(event.scrollingDeltaX) * scrollSensitivity,
            Float(event.scrollingDeltaY) * scrollSensitivity
        )
        
        self.scrollDelta = scrollDelta
        
        let mouseEvent = MouseEvent(
            type: .scroll,
            position: mousePosition,
            scrollDelta: scrollDelta
        )
        
        mousePublisher.send(mouseEvent)
    }
    
    private func handleGamepadConnection(_ notification: Notification) async {
        guard let gamepad = notification.object as? GCController else { return }
        setupGamepadInput(gamepad)
    }
    
    private func handleGamepadDisconnection(_ notification: Notification) async {
        // Clean up gamepad resources
    }
    
    private func setupGamepadInput(_ gamepad: GCController) {
        if let extendedGamepad = gamepad.extendedGamepad {
            extendedGamepad.valueChangedHandler = { [weak self] gamepad, element in
                self?.handleGamepadInput(controller: gamepad.controller!, element: element)
            }
        }
    }
    
    private func handleGamepadInput(controller: GCController, element: GCControllerElement) {
        let gamepadEvent = GamepadEvent(
            controller: controller,
            element: element,
            timestamp: CACurrentMediaTime()
        )
        
        gamepadPublisher.send(gamepadEvent)
    }
    
    private func getMouseEventType(_ event: NSEvent) -> MouseEventType {
        switch event.type {
        case .mouseMoved:
            return .move
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return .click
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            return .release
        case .scrollWheel:
            return .scroll
        default:
            return .move
        }
    }
    
    private func getMouseButton(_ event: NSEvent) -> MouseButton {
        switch event.type {
        case .leftMouseDown, .leftMouseUp:
            return .left
        case .rightMouseDown, .rightMouseUp:
            return .right
        case .otherMouseDown, .otherMouseUp:
            return .middle
        default:
            return .none
        }
    }
    
    private func updateMouseButtonStates(_ event: NSEvent) {
        let button = getMouseButton(event)
        
        if event.type == .leftMouseDown || event.type == .rightMouseDown || event.type == .otherMouseDown {
            mouseButtonStates.insert(button)
        } else if event.type == .leftMouseUp || event.type == .rightMouseUp || event.type == .otherMouseUp {
            mouseButtonStates.remove(button)
        }
    }
    
    private func handleKeyCombinations(_ event: NSEvent) {
        let flags = event.modifierFlags
        
        if flags.contains(.command) {
            switch event.keyCode {
            case 53: // Cmd + Escape
                NSApplication.shared.terminate(nil)
            case 3: // Cmd + F
                // Toggle fullscreen
                break
            default:
                break
            }
        }
        
        if flags.contains(.control) {
            switch event.keyCode {
            case 15: // Ctrl + Shift
                toggleMouseCapture()
            default:
                break
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        // Event monitors cleaned up automatically by NSEvent
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Data Structures
public struct MouseEvent: Sendable {
    public let type: MouseEventType
    public let position: SIMD2<Float>
    public let button: MouseButton
    public let clickCount: Int
    public let scrollDelta: SIMD2<Float>
    
    public init(type: MouseEventType, position: SIMD2<Float>, button: MouseButton = .none, clickCount: Int = 0, scrollDelta: SIMD2<Float> = SIMD2<Float>(0, 0)) {
        self.type = type
        self.position = position
        self.button = button
        self.clickCount = clickCount
        self.scrollDelta = scrollDelta
    }
}

public enum MouseEventType: Sendable {
    case move
    case click
    case release
    case scroll
}

public enum MouseButton: CaseIterable, Hashable, Sendable {
    case left
    case right
    case middle
    case none
}

public struct GamepadEvent {
    public let controller: GCController
    public let element: GCControllerElement
    public let timestamp: CFTimeInterval
    
    public init(controller: GCController, element: GCControllerElement, timestamp: CFTimeInterval) {
        self.controller = controller
        self.element = element
        self.timestamp = timestamp
    }
}

// MARK: - Gamepad Support
import GameController

extension InputManager {
    public func setupGamepadSupport() {
        GCController.startWirelessControllerDiscovery { }
    }
    
    public func stopGamepadDiscovery() {
        GCController.stopWirelessControllerDiscovery()
    }
    
    public func getConnectedGamepads() -> [GCController] {
        return GCController.controllers()
    }
    
    public func getGamepadInput(_ gamepad: GCController) -> GamepadInput? {
        guard let extendedGamepad = gamepad.extendedGamepad else { return nil }
        
        return GamepadInput(
            leftStick: SIMD2<Float>(Float(extendedGamepad.leftThumbstick.xAxis.value), Float(extendedGamepad.leftThumbstick.yAxis.value)),
            rightStick: SIMD2<Float>(Float(extendedGamepad.rightThumbstick.xAxis.value), Float(extendedGamepad.rightThumbstick.yAxis.value)),
            leftTrigger: Float(extendedGamepad.leftTrigger.value),
            rightTrigger: Float(extendedGamepad.rightTrigger.value),
            buttonA: extendedGamepad.buttonA.isPressed,
            buttonB: extendedGamepad.buttonB.isPressed,
            buttonX: extendedGamepad.buttonX.isPressed,
            buttonY: extendedGamepad.buttonY.isPressed,
            leftShoulder: extendedGamepad.leftShoulder.isPressed,
            rightShoulder: extendedGamepad.rightShoulder.isPressed,
            dpad: SIMD2<Float>(Float(extendedGamepad.dpad.xAxis.value), Float(extendedGamepad.dpad.yAxis.value))
        )
    }
}

public struct GamepadInput {
    public let leftStick: SIMD2<Float>
    public let rightStick: SIMD2<Float>
    public let leftTrigger: Float
    public let rightTrigger: Float
    public let buttonA: Bool
    public let buttonB: Bool
    public let buttonX: Bool
    public let buttonY: Bool
    public let leftShoulder: Bool
    public let rightShoulder: Bool
    public let dpad: SIMD2<Float>
    
    public init(leftStick: SIMD2<Float>, rightStick: SIMD2<Float>, leftTrigger: Float, rightTrigger: Float, buttonA: Bool, buttonB: Bool, buttonX: Bool, buttonY: Bool, leftShoulder: Bool, rightShoulder: Bool, dpad: SIMD2<Float>) {
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.leftTrigger = leftTrigger
        self.rightTrigger = rightTrigger
        self.buttonA = buttonA
        self.buttonB = buttonB
        self.buttonX = buttonX
        self.buttonY = buttonY
        self.leftShoulder = leftShoulder
        self.rightShoulder = rightShoulder
        self.dpad = dpad
    }
}
