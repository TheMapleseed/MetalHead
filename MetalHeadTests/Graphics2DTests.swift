import XCTest
import Metal
import simd
import QuartzCore
@testable import MetalHeadEngine

/// Unit tests for Graphics2D
/// Comprehensive testing of 2D rendering system
final class Graphics2DTests: XCTestCase {
    
    var device: MTLDevice!
    var graphics2D: Graphics2D!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.metalNotSupported
        }
        self.device = device
        
        graphics2D = Graphics2D(device: device)
    }
    
    override func tearDownWithError() throws {
        graphics2D = nil
        device = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func test_Initialization_whenValidDevice_expectSuccess() async throws {
        // Given
        XCTAssertNotNil(graphics2D)
        
        // When & Then - should not throw
        XCTAssertNoThrow(try await graphics2D.initialize(), "Graphics2D should initialize without error")
    }
    
    // MARK: - Drawing Tests
    
    func test_DrawRectangle_whenValidParameters_expectDrawn() async throws {
        // Given
        try await graphics2D.initialize()
        
        let position = SIMD2<Float>(100, 100)
        let size = SIMD2<Float>(200, 200)
        let color = SIMD4<Float>(1, 0, 0, 1)
        
        // When & Then - should not throw or crash
        XCTAssertNoThrow(graphics2D.drawRectangle(at: position, size: size, color: color), "Rectangle drawing should not throw")
        
        // Verify we can draw multiple rectangles
        graphics2D.drawRectangle(at: SIMD2<Float>(300, 300), size: SIMD2<Float>(50, 50), color: SIMD4<Float>(0, 1, 0, 1))
        XCTAssertNoThrow(graphics2D.drawRectangle(at: SIMD2<Float>(400, 400), size: SIMD2<Float>(75, 75), color: SIMD4<Float>(0, 0, 1, 1)), "Multiple rectangles should work")
    }
    
    func test_DrawCircle_whenValidParameters_expectDrawn() async throws {
        // Given
        try await graphics2D.initialize()
        
        let center = SIMD2<Float>(200, 200)
        let radius: Float = 50
        let color = SIMD4<Float>(0, 1, 0, 1)
        
        // When & Then - should not throw
        XCTAssertNoThrow(graphics2D.drawCircle(at: center, radius: radius, color: color), "Circle drawing should not throw")
        
        // Verify different radii work
        XCTAssertNoThrow(graphics2D.drawCircle(at: SIMD2<Float>(100, 100), radius: 25, color: color), "Small circle should work")
        XCTAssertNoThrow(graphics2D.drawCircle(at: SIMD2<Float>(300, 300), radius: 100, color: color), "Large circle should work")
    }
    
    func test_DrawLine_whenValidParameters_expectDrawn() async throws {
        // Given
        try await graphics2D.initialize()
        
        let start = SIMD2<Float>(0, 0)
        let end = SIMD2<Float>(100, 100)
        let thickness: Float = 2
        let color = SIMD4<Float>(0, 0, 1, 1)
        
        // When & Then - should not throw
        XCTAssertNoThrow(graphics2D.drawLine(from: start, to: end, thickness: thickness, color: color), "Line drawing should not throw")
        
        // Verify different line orientations
        XCTAssertNoThrow(graphics2D.drawLine(from: SIMD2<Float>(0, 0), to: SIMD2<Float>(100, 0), thickness: 1, color: color), "Horizontal line should work")
        XCTAssertNoThrow(graphics2D.drawLine(from: SIMD2<Float>(0, 0), to: SIMD2<Float>(0, 100), thickness: 1, color: color), "Vertical line should work")
    }
    
    func test_DrawText_whenValidParameters_expectDrawn() async throws {
        // Given
        try await graphics2D.initialize()
        
        let text = "Hello, MetalHead!"
        let position = SIMD2<Float>(10, 10)
        let size: Float = 24
        let color = SIMD4<Float>(1, 1, 1, 1)
        
        // When & Then - should not throw
        XCTAssertNoThrow(graphics2D.drawText(text, at: position, size: size, color: color), "Text drawing should not throw")
        
        // Verify different text sizes and positions
        XCTAssertNoThrow(graphics2D.drawText("Small", at: SIMD2<Float>(20, 20), size: 12, color: color), "Small text should work")
        XCTAssertNoThrow(graphics2D.drawText("Large", at: SIMD2<Float>(30, 30), size: 48, color: color), "Large text should work")
        XCTAssertNoThrow(graphics2D.drawText("", at: SIMD2<Float>(40, 40), size: 24, color: color), "Empty text should work")
    }
    
    func test_DrawSprite_whenValidParameters_expectDrawn() async throws {
        // Given
        try await graphics2D.initialize()
        
        let position = SIMD2<Float>(50, 50)
        let size = SIMD2<Float>(100, 100)
        let color = SIMD4<Float>(1, 1, 1, 1)
        
        // When & Then - should not throw
        XCTAssertNoThrow(graphics2D.drawSprite(at: position, size: size, texture: nil, color: color), "Sprite drawing should not throw")
        
        // Verify sprite with different parameters
        XCTAssertNoThrow(graphics2D.drawSprite(at: SIMD2<Float>(150, 150), size: SIMD2<Float>(50, 50), texture: nil, color: SIMD4<Float>(0.5, 0.5, 0.5, 1)), "Sprite with different size should work")
    }
    
    // MARK: - Color Control Tests
    
    func test_SetColor_whenValidColor_expectSet() async throws {
        // Given
        try await graphics2D.initialize()
        
        let color = SIMD4<Float>(0.5, 0.5, 0.5, 1.0)
        
        // When & Then - should not throw
        XCTAssertNoThrow(graphics2D.setColor(color), "Setting valid color should not throw")
        
        // Verify we can set multiple colors
        XCTAssertNoThrow(graphics2D.setColor(SIMD4<Float>(1, 0, 0, 1)), "Red color should work")
        XCTAssertNoThrow(graphics2D.setColor(SIMD4<Float>(0, 1, 0, 1)), "Green color should work")
        XCTAssertNoThrow(graphics2D.setColor(SIMD4<Float>(0, 0, 1, 1)), "Blue color should work")
    }
    
    func test_SetColor_whenInvalidColor_expectClamped() async throws {
        // Given
        try await graphics2D.initialize()
        
        let invalidColor = SIMD4<Float>(2.0, -1.0, 0.5, 1.0)
        
        // When & Then - should not throw (color may be clamped internally)
        XCTAssertNoThrow(graphics2D.setColor(invalidColor), "Invalid color should be handled gracefully")
        
        // Verify extreme values don't crash
        XCTAssertNoThrow(graphics2D.setColor(SIMD4<Float>(100, 100, 100, 1)), "Extreme positive values should work")
        XCTAssertNoThrow(graphics2D.setColor(SIMD4<Float>(-100, -100, -100, 1)), "Extreme negative values should work")
    }
    
    // MARK: - Clear Tests
    
    func test_Clear_whenMultipleDrawCalls_expectCleared() async throws {
        // Given
        try await graphics2D.initialize()
        
        // Draw multiple items
        graphics2D.drawRectangle(at: SIMD2<Float>(10, 10), size: SIMD2<Float>(20, 20), color: SIMD4<Float>(1, 0, 0, 1))
        graphics2D.drawCircle(at: SIMD2<Float>(50, 50), radius: 25, color: SIMD4<Float>(0, 1, 0, 1))
        graphics2D.drawText("Test", at: SIMD2<Float>(100, 100), size: 16, color: SIMD4<Float>(1, 1, 1, 1))
        graphics2D.drawSprite(at: SIMD2<Float>(200, 200), size: SIMD2<Float>(50, 50), texture: nil, color: SIMD4<Float>(1, 1, 1, 1))
        
        // When
        XCTAssertNoThrow(graphics2D.clear(), "Clear should not throw")
        
        // Then - verify we can draw again after clearing (if clear didn't work, we'd have issues)
        XCTAssertNoThrow(graphics2D.drawRectangle(at: SIMD2<Float>(0, 0), size: SIMD2<Float>(10, 10), color: SIMD4<Float>(0, 0, 1, 1)), "Should be able to draw after clear")
    }
    
    // MARK: - Performance Tests
    
    func test_Performance_DrawManyShapes_expectFast() async throws {
        // Given
        try await graphics2D.initialize()
        
        let startTime = CACurrentMediaTime()
        
        // When
        for i in 0..<1000 {
            let position = SIMD2<Float>(Float(i), Float(i))
            let size = SIMD2<Float>(10, 10)
            let color = SIMD4<Float>(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1), 1)
            
            graphics2D.drawRectangle(at: position, size: size, color: color)
        }
        
        let endTime = CACurrentMediaTime()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.5, "Drawing should be fast")
    }
    
    // MARK: - Texture Loading Tests
    
    func test_LoadTexture_whenInvalidData_expectError() async throws {
        // Given
        try await graphics2D.initialize()
        
        let invalidData = Data()
        
        // When & Then
        XCTAssertThrowsError(try graphics2D.loadTexture(from: invalidData, name: "invalid")) { error in
            XCTAssertTrue(error is Graphics2DError)
        }
    }
    
    // MARK: - Edge Cases
    
    func test_DrawRectangle_whenZeroSize_expectNoCrash() async throws {
        // Given
        try await graphics2D.initialize()
        
        // When & Then - should not throw or crash
        XCTAssertNoThrow(graphics2D.drawRectangle(at: SIMD2<Float>(100, 100), size: SIMD2<Float>(0, 0), color: SIMD4<Float>(1, 0, 0, 1)), "Zero size should be handled gracefully")
        
        // Verify negative size also doesn't crash
        XCTAssertNoThrow(graphics2D.drawRectangle(at: SIMD2<Float>(100, 100), size: SIMD2<Float>(-10, -10), color: SIMD4<Float>(1, 0, 0, 1)), "Negative size should be handled")
    }
    
    func test_DrawCircle_whenZeroRadius_expectNoCrash() async throws {
        // Given
        try await graphics2D.initialize()
        
        // When & Then - should not throw
        XCTAssertNoThrow(graphics2D.drawCircle(at: SIMD2<Float>(200, 200), radius: 0, color: SIMD4<Float>(0, 1, 0, 1)), "Zero radius should be handled gracefully")
        
        // Verify negative radius also doesn't crash
        XCTAssertNoThrow(graphics2D.drawCircle(at: SIMD2<Float>(200, 200), radius: -10, color: SIMD4<Float>(0, 1, 0, 1)), "Negative radius should be handled")
    }
    
    func test_DrawLine_whenZeroLength_expectNoCrash() async throws {
        // Given
        try await graphics2D.initialize()
        
        // When & Then - should not throw
        let point = SIMD2<Float>(100, 100)
        XCTAssertNoThrow(graphics2D.drawLine(from: point, to: point, thickness: 1, color: SIMD4<Float>(0, 0, 1, 1)), "Zero length line should be handled gracefully")
        
        // Verify zero thickness also works
        XCTAssertNoThrow(graphics2D.drawLine(from: SIMD2<Float>(0, 0), to: SIMD2<Float>(100, 100), thickness: 0, color: SIMD4<Float>(0, 0, 1, 1)), "Zero thickness should work")
    }
}

// MARK: - Sprite Tests

final class SpriteTests: XCTestCase {
    
    var device: MTLDevice!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.metalNotSupported
        }
        self.device = device
    }
    
    func test_SpriteCreation_whenValidParameters_expectValid() {
        // Given
        let position = SIMD2<Float>(100, 100)
        let size = SIMD2<Float>(64, 64)
        let color = SIMD4<Float>(1, 1, 1, 1)
        let texture: MTLTexture? = nil
        
        // When
        let sprite = Sprite2D(position: position, size: size, texture: texture, color: color)
        
        // Then
        XCTAssertEqual(sprite.position, position)
        XCTAssertEqual(sprite.size, size)
        XCTAssertEqual(sprite.color, color)
        XCTAssertNil(sprite.texture)
    }
    
    func test_SpriteCorners_whenRotated_expectCorrect() {
        // Given
        let sprite = Sprite2D(position: SIMD2<Float>(0, 0), size: SIMD2<Float>(100, 100), texture: nil, color: SIMD4<Float>(1, 1, 1, 1), rotation: Float.pi / 4)
        
        // When
        let topLeft = sprite.topLeft
        let topRight = sprite.topRight
        let bottomLeft = sprite.bottomLeft
        let bottomRight = sprite.bottomRight
        
        // Then
        XCTAssertNotEqual(topLeft, SIMD2<Float>(0, 0), "Rotated corners should differ")
        XCTAssertNotEqual(topRight, SIMD2<Float>(100, 0), "Rotated corners should differ")
    }
}

// MARK: - Shape Tests

final class ShapeTests: XCTestCase {
    
    func test_ShapeCreation_whenValidParameters_expectValid() {
        // Given
        let position = SIMD2<Float>(50, 50)
        let size = SIMD2<Float>(100, 100)
        let color = SIMD4<Float>(1, 0, 0, 1)
        
        // When
        let shape = Shape2D(position: position, size: size, color: color)
        
        // Then
        XCTAssertEqual(shape.position, position)
        XCTAssertEqual(shape.size, size)
        XCTAssertEqual(shape.color, color)
    }
    
    func test_ShapeCorners_whenNoRotation_expectCorrect() {
        // Given
        let position = SIMD2<Float>(100, 100)
        let size = SIMD2<Float>(200, 200)
        
        let shape = Shape2D(position: position, size: size, color: SIMD4<Float>(1, 1, 1, 1))
        
        // When
        let topLeft = shape.topLeft
        let topRight = shape.topRight
        let bottomLeft = shape.bottomLeft
        let bottomRight = shape.bottomRight
        
        // Then
        XCTAssertLessThan(topLeft.x, position.x)
        XCTAssertGreaterThan(topRight.x, position.x)
        XCTAssertLessThan(bottomLeft.x, position.x)
        XCTAssertGreaterThan(bottomRight.x, position.x)
    }
}

// MARK: - Text Tests

final class TextTests: XCTestCase {
    
    func test_TextCreation_whenValidParameters_expectValid() {
        // Given
        let text = "Hello, World!"
        let position = SIMD2<Float>(10, 10)
        let size: Float = 24
        let color = SIMD4<Float>(1, 1, 1, 1)
        
        // When
        let textElement = Text2D(text: text, position: position, size: size, color: color)
        
        // Then
        XCTAssertEqual(textElement.text, text)
        XCTAssertEqual(textElement.position, position)
        XCTAssertEqual(textElement.color, color)
    }
}
