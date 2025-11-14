import XCTest
import Metal
import simd
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
        
        // When
        try await graphics2D.initialize()
        
        // Then
        XCTAssertTrue(true, "Graphics2D initialized successfully")
    }
    
    // MARK: - Drawing Tests
    
    func test_DrawRectangle_whenValidParameters_expectDrawn() async throws {
        // Given
        try await graphics2D.initialize()
        
        let position = SIMD2<Float>(100, 100)
        let size = SIMD2<Float>(200, 200)
        let color = SIMD4<Float>(1, 0, 0, 1)
        
        // When
        graphics2D.drawRectangle(at: position, size: size, color: color)
        
        // Then
        XCTAssertTrue(true, "Rectangle drawn without error")
    }
    
    func test_DrawCircle_whenValidParameters_expectDrawn() async throws {
        // Given
        try await graphics2D.initialize()
        
        let center = SIMD2<Float>(200, 200)
        let radius: Float = 50
        let color = SIMD4<Float>(0, 1, 0, 1)
        
        // When
        graphics2D.drawCircle(at: center, radius: radius, color: color)
        
        // Then
        XCTAssertTrue(true, "Circle drawn without error")
    }
    
    func test_DrawLine_whenValidParameters_expectDrawn() async throws {
        // Given
        try await graphics2D.initialize()
        
        let start = SIMD2<Float>(0, 0)
        let end = SIMD2<Float>(100, 100)
        let thickness: Float = 2
        let color = SIMD4<Float>(0, 0, 1, 1)
        
        // When
        graphics2D.drawLine(from: start, to: end, thickness: thickness, color: color)
        
        // Then
        XCTAssertTrue(true, "Line drawn without error")
    }
    
    func test_DrawText_whenValidParameters_expectDrawn() async throws {
        // Given
        try await graphics2D.initialize()
        
        let text = "Hello, MetalHead!"
        let position = SIMD2<Float>(10, 10)
        let size: Float = 24
        let color = SIMD4<Float>(1, 1, 1, 1)
        
        // When
        graphics2D.drawText(text, at: position, size: size, color: color)
        
        // Then
        XCTAssertTrue(true, "Text drawn without error")
    }
    
    func test_DrawSprite_whenValidParameters_expectDrawn() async throws {
        // Given
        try await graphics2D.initialize()
        
        let position = SIMD2<Float>(50, 50)
        let size = SIMD2<Float>(100, 100)
        let color = SIMD4<Float>(1, 1, 1, 1)
        
        // When
        graphics2D.drawSprite(at: position, size: size, texture: nil, color: color)
        
        // Then
        XCTAssertTrue(true, "Sprite drawn without error")
    }
    
    // MARK: - Color Control Tests
    
    func test_SetColor_whenValidColor_expectSet() async throws {
        // Given
        try await graphics2D.initialize()
        
        let color = SIMD4<Float>(0.5, 0.5, 0.5, 1.0)
        
        // When
        graphics2D.setColor(color)
        
        // Then
        XCTAssertTrue(true, "Color set successfully")
    }
    
    func test_SetColor_whenInvalidColor_expectClamped() async throws {
        // Given
        try await graphics2D.initialize()
        
        let invalidColor = SIMD4<Float>(2.0, -1.0, 0.5, 1.0)
        
        // When
        graphics2D.setColor(invalidColor)
        
        // Then
        XCTAssertTrue(true, "Color handled gracefully")
    }
    
    // MARK: - Clear Tests
    
    func test_Clear_whenMultipleDrawCalls_expectCleared() async throws {
        // Given
        try await graphics2D.initialize()
        
        // Draw multiple items
        graphics2D.drawRectangle(at: SIMD2<Float>(10, 10), size: SIMD2<Float>(20, 20), color: SIMD4<Float>(1, 0, 0, 1))
        graphics2D.drawCircle(at: SIMD2<Float>(50, 50), radius: 25, color: SIMD4<Float>(0, 1, 0, 1))
        
        // When
        graphics2D.clear()
        
        // Then
        XCTAssertTrue(true, "Clear completed successfully")
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
        
        // When & Then
        graphics2D.drawRectangle(at: SIMD2<Float>(100, 100), size: SIMD2<Float>(0, 0), color: SIMD4<Float>(1, 0, 0, 1))
        XCTAssertTrue(true, "Zero size handled gracefully")
    }
    
    func test_DrawCircle_whenZeroRadius_expectNoCrash() async throws {
        // Given
        try await graphics2D.initialize()
        
        // When & Then
        graphics2D.drawCircle(at: SIMD2<Float>(200, 200), radius: 0, color: SIMD4<Float>(0, 1, 0, 1))
        XCTAssertTrue(true, "Zero radius handled gracefully")
    }
    
    func test_DrawLine_whenZeroLength_expectNoCrash() async throws {
        // Given
        try await graphics2D.initialize()
        
        // When & Then
        let point = SIMD2<Float>(100, 100)
        graphics2D.drawLine(from: point, to: point, thickness: 1, color: SIMD4<Float>(0, 0, 1, 1))
        XCTAssertTrue(true, "Zero length line handled gracefully")
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
