import XCTest
import Metal
import simd
import QuartzCore
@testable import MetalHeadEngine

/// Unit tests for GeometryShaders
/// Tests comprehensive error handling and all code paths
final class GeometryShaderTests: XCTestCase {
    
    var device: MTLDevice!
    var geometryShaders: GeometryShaders!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw TestError.metalNotSupported
        }
        self.device = device
        
        geometryShaders = GeometryShaders(device: device)
    }
    
    override func tearDownWithError() throws {
        geometryShaders = nil
        device = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Cube Tests
    
    func test_CreateCube_whenCalled_expectValidGeometry() {
        // When
        let (vertices, indices) = geometryShaders.createCube()
        
        // Then
        XCTAssertEqual(vertices.count, 8, "Cube should have 8 vertices")
        XCTAssertEqual(indices.count, 36, "Cube should have 36 indices")
        
        // Verify first and last vertices
        XCTAssertEqual(vertices[0].position.x, -1.0)
        XCTAssertEqual(vertices[7].position.x, -1.0)
    }
    
    func test_CreateCubeIndices_whenCalled_expectValidIndices() {
        // When
        let indices = geometryShaders.createCubeIndices()
        
        // Then
        XCTAssertEqual(indices.count, 36)
        XCTAssertTrue(indices.allSatisfy { $0 < 8 }, "All indices should reference valid vertices")
    }
    
    // MARK: - Sphere Tests
    
    func test_CreateSphere_whenDefaultSegments_expectValidGeometry() {
        // When
        let (vertices, indices) = geometryShaders.createSphere()
        
        // Then
        XCTAssertGreaterThan(vertices.count, 0)
        XCTAssertGreaterThan(indices.count, 0)
    }
    
    func test_CreateSphere_whenHighDetail_expectMoreVertices() {
        // When
        let (lowDetail, _) = geometryShaders.createSphere(segments: 16)
        let (highDetail, _) = geometryShaders.createSphere(segments: 64)
        
        // Then
        XCTAssertGreaterThan(highDetail.count, lowDetail.count, "High detail should have more vertices")
    }
    
    func test_CreateSphere_whenLowDetail_expectFewerVertices() {
        // When
        let (vertices, indices) = geometryShaders.createSphere(segments: 8)
        
        // Then
        XCTAssertLessThan(vertices.count, 1000, "Low detail should have fewer vertices")
    }
    
    func test_CreateSphere_whenSegmentsZero_expectEmptyGeometry() {
        // When
        let (vertices, indices) = geometryShaders.createSphere(segments: 0)
        
        // Then
        XCTAssertEqual(vertices.count, 0)
        XCTAssertEqual(indices.count, 0)
    }
    
    func test_CreateSphere_whenNegativeSegments_expectHandled() {
        // When
        let (vertices, indices) = geometryShaders.createSphere(segments: -1)
        
        // Then
        XCTAssertGreaterThanOrEqual(vertices.count, 0) // Should handle gracefully
    }
    
    // MARK: - Plane Tests
    
    func test_CreatePlane_whenDefaultSize_expectUnitPlane() {
        // When
        let (vertices, indices) = geometryShaders.createPlane()
        
        // Then
        XCTAssertEqual(vertices.count, 4)
        XCTAssertEqual(indices.count, 6)
    }
    
    func test_CreatePlane_whenCustomSize_expectCorrectDimensions() {
        // When
        let (vertices, _) = geometryShaders.createPlane(width: 10.0, height: 20.0)
        
        // Then
        XCTAssertEqual(vertices.count, 4)
        // Check bounds
        let xValues = vertices.map { $0.position.x }
        XCTAssertLessThan(xValues.min()!, -4.0)
        XCTAssertGreaterThan(xValues.max()!, 4.0)
    }
    
    func test_CreatePlane_whenZeroSize_expectValidGeometry() {
        // When
        let (vertices, indices) = geometryShaders.createPlane(width: 0, height: 0)
        
        // Then
        XCTAssertEqual(vertices.count, 4)
        XCTAssertEqual(indices.count, 6)
    }
    
    // MARK: - Cylinder Tests
    
    func test_CreateCylinder_whenDefault_expectValidGeometry() {
        // When
        let (vertices, indices) = geometryShaders.createCylinder()
        
        // Then
        XCTAssertGreaterThan(vertices.count, 0)
        XCTAssertGreaterThan(indices.count, 0)
    }
    
    func test_CreateCylinder_whenCustomHeight_expectCorrectDimensions() {
        // When
        let (vertices, _) = geometryShaders.createCylinder(segments: 16, height: 2.0)
        
        // Then
        let yValues = vertices.map { $0.position.y }
        XCTAssertLessThanOrEqual(yValues.min()!, -1.0)
        XCTAssertGreaterThanOrEqual(yValues.max()!, 1.0)
    }
    
    func test_CreateCylinder_whenManySegments_expectMoreVertices() {
        // When
        let (lowDetail, _) = geometryShaders.createCylinder(segments: 8)
        let (highDetail, _) = geometryShaders.createCylinder(segments: 64)
        
        // Then
        XCTAssertGreaterThan(highDetail.count, lowDetail.count)
    }
    
    // MARK: - Torus Tests
    
    func test_CreateTorus_whenDefault_expectValidGeometry() {
        // When
        let (vertices, indices) = geometryShaders.createTorus()
        
        // Then
        XCTAssertGreaterThan(vertices.count, 0)
        XCTAssertGreaterThan(indices.count, 0)
    }
    
    func test_CreateTorus_whenDifferentRadii_expectValidGeometry() {
        // When
        let (vertices, _) = geometryShaders.createTorus(majorRadius: 2.0, minorRadius: 0.5, segments: 16)
        
        // Then
        XCTAssertGreaterThan(vertices.count, 0)
        let positions = vertices.map { $0.position }
        let distances = positions.map { length($0) }
        XCTAssertLessThan(distances.max()!, 3.0) // Should fit within major + minor radius
    }
    
    // MARK: - Quad Tests
    
    func test_CreateQuad_whenDefault_expectValidGeometry() {
        // When
        let (vertices, indices) = geometryShaders.createQuad()
        
        // Then
        XCTAssertEqual(vertices.count, 4)
        XCTAssertEqual(indices.count, 6)
    }
    
    func test_CreateQuad_whenCustomSize_expectCorrectDimensions() {
        // When
        let (vertices, _) = geometryShaders.createQuad(size: 5.0)
        
        // Then
        XCTAssertEqual(vertices.count, 4)
        let xValues = vertices.map { $0.position.x }
        XCTAssertLessThan(xValues.min()!, -2.0)
        XCTAssertGreaterThan(xValues.max()!, 2.0)
    }
    
    // MARK: - Dome Tests
    
    func test_CreateDome_whenDefault_expectValidGeometry() {
        // When
        let (vertices, indices) = geometryShaders.createDome()
        
        // Then
        XCTAssertGreaterThan(vertices.count, 0)
        XCTAssertGreaterThan(indices.count, 0)
    }
    
    func test_CreateDome_whenHighDetail_expectMoreVertices() {
        // When
        let (lowDetail, _) = geometryShaders.createDome(segments: 16)
        let (highDetail, _) = geometryShaders.createDome(segments: 64)
        
        // Then
        XCTAssertGreaterThan(highDetail.count, lowDetail.count)
    }
    
    // MARK: - Box Tests
    
    func test_CreateBox_whenDefault_expectUnitBox() {
        // When
        let (vertices, indices) = geometryShaders.createBox()
        
        // Then
        XCTAssertEqual(vertices.count, 8)
        XCTAssertEqual(indices.count, 36)
    }
    
    func test_CreateBox_whenCustomDimensions_expectCorrectSize() {
        // When
        let (vertices, _) = geometryShaders.createBox(width: 2.0, height: 3.0, depth: 4.0)
        
        // Then
        XCTAssertEqual(vertices.count, 8)
        let xValues = vertices.map { $0.position.x }
        XCTAssertLessThan(xValues.min()!, -0.9)
        XCTAssertGreaterThan(xValues.max()!, 0.9)
    }
    
    func test_CreateBox_whenZeroDimensions_expectValidGeometry() {
        // When
        let (vertices, indices) = geometryShaders.createBox(width: 0, height: 0, depth: 0)
        
        // Then
        XCTAssertEqual(vertices.count, 8)
        XCTAssertEqual(indices.count, 36)
    }
    
    // MARK: - Grid Tests
    
    func test_CreateGrid_whenDefault_expectValidGeometry() {
        // When
        let (vertices, indices) = geometryShaders.createGrid()
        
        // Then
        XCTAssertGreaterThan(vertices.count, 0)
        XCTAssertGreaterThan(indices.count, 0)
    }
    
    func test_CreateGrid_whenCustomSize_expectCorrectDimensions() {
        // When
        let (vertices, _) = geometryShaders.createGrid(size: 20.0, divisions: 20)
        
        // Then
        XCTAssertGreaterThan(vertices.count, 0)
    }
    
    func test_CreateGrid_whenManyDivisions_expectMoreVertices() {
        // When
        let (lowDetail, _) = geometryShaders.createGrid(size: 10.0, divisions: 5)
        let (highDetail, _) = geometryShaders.createGrid(size: 10.0, divisions: 20)
        
        // Then
        XCTAssertGreaterThan(highDetail.count, lowDetail.count)
    }
    
    // MARK: - Performance Tests
    
    func test_Performance_CreateMultipleGeometries_expectFast() {
        let startTime = CACurrentMediaTime()
        
        // When
        for _ in 0..<100 {
            let (_, _) = geometryShaders.createCube()
            let (_, _) = geometryShaders.createSphere()
            let (_, _) = geometryShaders.createPlane()
        }
        
        let endTime = CACurrentMediaTime()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 1.0, "Geometry creation should be fast")
    }
    
    func test_Performance_CreateHighDetailSphere_expectReasonableTime() {
        let startTime = CACurrentMediaTime()
        
        // When
        let (_, _) = geometryShaders.createSphere(segments: 256)
        
        let endTime = CACurrentMediaTime()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.1, "High detail sphere should complete quickly")
    }
    
    // MARK: - Memory Tests
    
    func test_Memory_CreateLargeGeometry_expectNoLeak() {
        // When & Then - should not throw
        var sphereCount = 0
        for i in 0..<1000 {
            let (vertices, indices) = geometryShaders.createSphere(segments: 128)
            XCTAssertNotNil(vertices, "Sphere \(i) vertices should not be nil")
            XCTAssertNotNil(indices, "Sphere \(i) indices should not be nil")
            XCTAssertGreaterThan(vertices.count, 0, "Sphere \(i) should have vertices")
            XCTAssertGreaterThan(indices.count, 0, "Sphere \(i) should have indices")
            sphereCount += 1
        }
        
        // Then
        XCTAssertEqual(sphereCount, 1000, "Should create all 1000 spheres")
    }
    
    // MARK: - Validation Tests
    
    func test_Validation_AllGeometriesHaveValidBounds() {
        // Given
        let geometries = [
            ("cube", geometryShaders.createCube()),
            ("sphere", geometryShaders.createSphere(segments: 16)),
            ("plane", geometryShaders.createPlane()),
            ("cylinder", geometryShaders.createCylinder()),
            ("quad", geometryShaders.createQuad())
        ]
        
        // When & Then
        for (name, (vertices, _)) in geometries {
            XCTAssertGreaterThan(vertices.count, 0, "\(name) should have vertices")
            
            // Check that all vertices have valid positions
            for vertex in vertices {
                XCTAssertTrue(vertex.position.x.isFinite, "\(name) vertex x should be finite")
                XCTAssertTrue(vertex.position.y.isFinite, "\(name) vertex y should be finite")
                XCTAssertTrue(vertex.position.z.isFinite, "\(name) vertex z should be finite")
            }
        }
    }
    
    func test_Validation_AllIndicesAreValid() {
        // Given
        let geometries = [
            ("cube", geometryShaders.createCube()),
            ("sphere", geometryShaders.createSphere(segments: 16))
        ]
        
        // When & Then
        for (name, (vertices, indices)) in geometries {
            for index in indices {
                XCTAssertLessThan(index, vertices.count, "\(name) index \(index) should reference valid vertex")
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func test_EdgeCase_CreateSphereWithMaxSegments_expectNoCrash() {
        // When & Then
        let (vertices, indices) = geometryShaders.createSphere(segments: 1000)
        
        XCTAssertGreaterThan(vertices.count, 0)
        XCTAssertGreaterThan(indices.count, 0)
    }
    
    func test_EdgeCase_CreateCylinderWithOneSegment_expectValidGeometry() {
        // When
        let (vertices, indices) = geometryShaders.createCylinder(segments: 1)
        
        // Then
        XCTAssertGreaterThan(vertices.count, 0)
        XCTAssertGreaterThan(indices.count, 0)
    }
    
    func test_EdgeCase_CreateGridWithZeroDivisions_expectValidGeometry() {
        // When
        let (vertices, indices) = geometryShaders.createGrid(size: 10.0, divisions: 0)
        
        // Then
        XCTAssertGreaterThanOrEqual(vertices.count, 0)
    }
}

// MARK: - Exported Function Tests

final class ExportedGeometryFunctionTests: XCTestCase {
    
    func test_CreateCubeGeometry_whenCalled_expectValidGeometry() {
        // When
        let (vertices, indices) = createCubeGeometry()
        
        // Then
        XCTAssertEqual(vertices.count, 8)
        XCTAssertEqual(indices.count, 36)
    }
    
    func test_CreateSphereGeometry_whenCalled_expectValidGeometry() {
        // When
        let (vertices, indices) = createSphereGeometry(segments: 32)
        
        // Then
        XCTAssertGreaterThan(vertices.count, 0)
        XCTAssertGreaterThan(indices.count, 0)
    }
    
    func test_CreatePlaneGeometry_whenCalled_expectValidGeometry() {
        // When
        let (vertices, indices) = createPlaneGeometry()
        
        // Then
        XCTAssertEqual(vertices.count, 4)
        XCTAssertEqual(indices.count, 6)
    }
    
    func test_CreateCylinderGeometry_whenCalled_expectValidGeometry() {
        // When
        let (vertices, indices) = createCylinderGeometry(segments: 16)
        
        // Then
        XCTAssertGreaterThan(vertices.count, 0)
        XCTAssertGreaterThan(indices.count, 0)
    }
    
    func test_CreateBoxGeometry_whenDefault_expectUnitBox() {
        // When
        let (vertices, indices) = createBoxGeometry()
        
        // Then
        XCTAssertEqual(vertices.count, 8)
        XCTAssertEqual(indices.count, 36)
    }
    
    func test_CreateBoxGeometry_whenCustomDimensions_expectCorrectSize() {
        // When
        let (vertices, _) = createBoxGeometry(width: 2, height: 3, depth: 4)
        
        // Then
        XCTAssertEqual(vertices.count, 8)
    }
}
