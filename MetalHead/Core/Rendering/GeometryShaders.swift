import Metal
import MetalKit
import simd
import Foundation

/// Pre-built geometry shader library for common shapes
/// Accelerates rendering by providing optimized geometry definitions
@MainActor
public class GeometryShaders: ObservableObject {
    private let device: MTLDevice
    
    // MARK: - Initialization
    public init(device: MTLDevice) {
        self.device = device
    }
    
    // MARK: - Primitive Geometries
    
    /// Create a unit cube geometry
    public func createCube() -> [Vertex] {
        return [
            // Front face
            Vertex(position: SIMD3<Float>(-1, -1,  1), color: SIMD4<Float>(1, 0, 0, 1)),
            Vertex(position: SIMD3<Float>( 1, -1,  1), color: SIMD4<Float>(0, 1, 0, 1)),
            Vertex(position: SIMD3<Float>( 1,  1,  1), color: SIMD4<Float>(0, 0, 1, 1)),
            Vertex(position: SIMD3<Float>(-1,  1,  1), color: SIMD4<Float>(1, 1, 0, 1)),
            // Back face
            Vertex(position: SIMD3<Float>(-1, -1, -1), color: SIMD4<Float>(1, 0, 1, 1)),
            Vertex(position: SIMD3<Float>( 1, -1, -1), color: SIMD4<Float>(0, 1, 1, 1)),
            Vertex(position: SIMD3<Float>( 1,  1, -1), color: SIMD4<Float>(1, 1, 1, 1)),
            Vertex(position: SIMD3<Float>(-1,  1, -1), color: SIMD4<Float>(0.5, 0.5, 0.5, 1))
        ]
    }
    
    /// Create cube indices
    public func createCubeIndices() -> [UInt16] {
        return [
            0, 1, 2, 2, 3, 0,  // Front
            4, 5, 6, 6, 7, 4,  // Back
            7, 3, 0, 0, 4, 7,  // Left
            1, 5, 6, 6, 2, 1,  // Right
            3, 2, 6, 6, 7, 3,  // Top
            0, 1, 5, 5, 4, 0   // Bottom
        ]
    }
    
    /// Create a sphere geometry
    public func createSphere(segments: Int = 32) -> ([Vertex], [UInt16]) {
        var vertices: [Vertex] = []
        var indices: [UInt16] = []
        
        // Generate sphere vertices
        for lat in 0...segments {
            let theta = Float.pi * Float(lat) / Float(segments)
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)
            
            for long in 0...segments {
                let phi = 2.0 * Float.pi * Float(long) / Float(segments)
                let sinPhi = sin(phi)
                let cosPhi = cos(phi)
                
                let x = cosPhi * sinTheta
                let y = cosTheta
                let z = sinPhi * sinTheta
                
                let position = SIMD3<Float>(x, y, z)
                let color = SIMD4<Float>(1, 1, 1, 1)
                
                vertices.append(Vertex(position: position, color: color))
            }
        }
        
        // Generate sphere indices
        for lat in 0..<segments {
            for long in 0..<segments {
                let first = UInt16(lat * (segments + 1) + long)
                let second = UInt16(first + 1)
                
                indices.append(first)
                indices.append(UInt16(first + segments + 1))
                indices.append(second)
                
                indices.append(second)
                indices.append(UInt16(first + segments + 1))
                indices.append(UInt16(second + segments + 1))
            }
        }
        
        return (vertices, indices)
    }
    
    /// Create a plane geometry
    public func createPlane(width: Float = 1.0, height: Float = 1.0) -> ([Vertex], [UInt16]) {
        let hw = width / 2.0
        let hh = height / 2.0
        
        let vertices: [Vertex] = [
            Vertex(position: SIMD3<Float>(-hw, -hh, 0), color: SIMD4<Float>(1, 1, 1, 1)),
            Vertex(position: SIMD3<Float>( hw, -hh, 0), color: SIMD4<Float>(1, 1, 1, 1)),
            Vertex(position: SIMD3<Float>( hw,  hh, 0), color: SIMD4<Float>(1, 1, 1, 1)),
            Vertex(position: SIMD3<Float>(-hw,  hh, 0), color: SIMD4<Float>(1, 1, 1, 1))
        ]
        
        let indices: [UInt16] = [0, 1, 2, 2, 3, 0]
        
        return (vertices, indices)
    }
    
    /// Create a cylinder geometry
    public func createCylinder(segments: Int = 16, height: Float = 1.0) -> ([Vertex], [UInt16]) {
        var vertices: [Vertex] = []
        var indices: [UInt16] = []
        
        // Bottom cap
        vertices.append(Vertex(position: SIMD3<Float>(0, -height/2, 0), color: SIMD4<Float>(1, 1, 1, 1)))
        
        // Side vertices
        for i in 0...segments {
            let angle = 2.0 * Float.pi * Float(i) / Float(segments)
            let x = cos(angle)
            let z = sin(angle)
            
            // Bottom vertices
            vertices.append(Vertex(position: SIMD3<Float>(x, -height/2, z), color: SIMD4<Float>(1, 1, 1, 1)))
            // Top vertices
            vertices.append(Vertex(position: SIMD3<Float>(x,  height/2, z), color: SIMD4<Float>(1, 1, 1, 1)))
        }
        
        // Top cap
        vertices.append(Vertex(position: SIMD3<Float>(0, height/2, 0), color: SIMD4<Float>(1, 1, 1, 1)))
        
        // Generate indices for sides
        for i in 0..<segments {
            let base = UInt16(1 + i * 2)
            indices.append(base)
            indices.append(UInt16(base + 1))
            indices.append(UInt16(base + 2))
            
            indices.append(UInt16(base + 1))
            indices.append(UInt16(base + 3))
            indices.append(UInt16(base + 2))
        }
        
        return (vertices, indices)
    }
    
    /// Create a torus geometry
    public func createTorus(majorRadius: Float = 0.5, minorRadius: Float = 0.25, segments: Int = 16) -> ([Vertex], [UInt16]) {
        var vertices: [Vertex] = []
        var indices: [UInt16] = []
        
        let totalSegments = segments
        let rings = segments
        
        // Generate vertices
        for i in 0...rings {
            let theta = 2.0 * Float.pi * Float(i) / Float(rings)
            let cosTheta = cos(theta)
            let sinTheta = sin(theta)
            
            for j in 0...totalSegments {
                let phi = 2.0 * Float.pi * Float(j) / Float(totalSegments)
                let cosPhi = cos(phi)
                let sinPhi = sin(phi)
                
                let x = (majorRadius + minorRadius * cosPhi) * cosTheta
                let y = (majorRadius + minorRadius * cosPhi) * sinTheta
                let z = minorRadius * sinPhi
                
                vertices.append(Vertex(position: SIMD3<Float>(x, y, z), color: SIMD4<Float>(1, 1, 1, 1)))
            }
        }
        
        // Generate indices
        for i in 0..<rings {
            for j in 0..<totalSegments {
                let current = UInt16(i * (totalSegments + 1) + j)
                let next = UInt16(current + totalSegments + 1)
                
                indices.append(current)
                indices.append(next)
                indices.append(UInt16(current + 1))
                
                indices.append(UInt16(current + 1))
                indices.append(next)
                indices.append(UInt16(next + 1))
            }
        }
        
        return (vertices, indices)
    }
    
    /// Create a quad geometry (optimized plane)
    public func createQuad(size: Float = 1.0) -> ([Vertex], [UInt16]) {
        let hSize = size / 2.0
        
        let vertices: [Vertex] = [
            Vertex(position: SIMD3<Float>(-hSize, -hSize, 0), color: SIMD4<Float>(1, 1, 1, 1)),
            Vertex(position: SIMD3<Float>( hSize, -hSize, 0), color: SIMD4<Float>(1, 1, 1, 1)),
            Vertex(position: SIMD3<Float>( hSize,  hSize, 0), color: SIMD4<Float>(1, 1, 1, 1)),
            Vertex(position: SIMD3<Float>(-hSize,  hSize, 0), color: SIMD4<Float>(1, 1, 1, 1))
        ]
        
        let indices: [UInt16] = [0, 1, 2, 2, 3, 0]
        
        return (vertices, indices)
    }
    
    /// Create a dome/hemisphere geometry
    public func createDome(segments: Int = 32) -> ([Vertex], [UInt16]) {
        var vertices: [Vertex] = []
        var indices: [UInt16] = []
        
        // Center vertex
        vertices.append(Vertex(position: SIMD3<Float>(0, 1, 0), color: SIMD4<Float>(1, 1, 1, 1)))
        
        // Generate dome
        for lat in 0...segments/2 {
            let theta = Float.pi * Float(lat) / Float(segments)
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)
            
            for long in 0...segments {
                let phi = 2.0 * Float.pi * Float(long) / Float(segments)
                let sinPhi = sin(phi)
                let cosPhi = cos(phi)
                
                let x = cosPhi * sinTheta
                let y = cosTheta
                let z = sinPhi * sinTheta
                
                vertices.append(Vertex(position: SIMD3<Float>(x, y, z), color: SIMD4<Float>(1, 1, 1, 1)))
            }
        }
        
        // Generate indices
        for lat in 0..<segments/2 {
            for long in 0..<segments {
                let first = UInt16(lat * (segments + 1) + long + 1)
                let second = UInt16(first + segments + 1)
                
                indices.append(0) // Center
                indices.append(first)
                indices.append(second)
                
                indices.append(first)
                indices.append(UInt16(first + 1))
                indices.append(second)
            }
        }
        
        return (vertices, indices)
    }
}

// MARK: - Public API Extensions

extension GeometryShaders {
    
    /// Create a box with custom dimensions
    public func createBox(width: Float, height: Float, depth: Float) -> ([Vertex], [UInt16]) {
        let hw = width / 2.0
        let hh = height / 2.0
        let hd = depth / 2.0
        
        let vertices: [Vertex] = [
            // Front face
            Vertex(position: SIMD3<Float>(-hw, -hh,  hd), color: SIMD4<Float>(1, 0, 0, 1)),
            Vertex(position: SIMD3<Float>( hw, -hh,  hd), color: SIMD4<Float>(0, 1, 0, 1)),
            Vertex(position: SIMD3<Float>( hw,  hh,  hd), color: SIMD4<Float>(0, 0, 1, 1)),
            Vertex(position: SIMD3<Float>(-hw,  hh,  hd), color: SIMD4<Float>(1, 1, 0, 1)),
            // Back face
            Vertex(position: SIMD3<Float>(-hw, -hh, -hd), color: SIMD4<Float>(1, 0, 1, 1)),
            Vertex(position: SIMD3<Float>( hw, -hh, -hd), color: SIMD4<Float>(0, 1, 1, 1)),
            Vertex(position: SIMD3<Float>( hw,  hh, -hd), color: SIMD4<Float>(1, 1, 1, 1)),
            Vertex(position: SIMD3<Float>(-hw,  hh, -hd), color: SIMD4<Float>(0.5, 0.5, 0.5, 1))
        ]
        
        let indices: [UInt16] = [
            0, 1, 2, 2, 3, 0,  // Front
            4, 5, 6, 6, 7, 4,  // Back
            7, 3, 0, 0, 4, 7,  // Left
            1, 5, 6, 6, 2, 1,  // Right
            3, 2, 6, 6, 7, 3,  // Top
            0, 1, 5, 5, 4, 0   // Bottom
        ]
        
        return (vertices, indices)
    }
    
    /// Create a wireframe grid
    public func createGrid(size: Float = 10.0, divisions: Int = 10) -> ([Vertex], [UInt16]) {
        var vertices: [Vertex] = []
        var indices: [UInt16] = []
        
        let step = size / Float(divisions)
        let halfSize = size / 2.0
        
        // Horizontal lines
        for i in 0...divisions {
            let y = -halfSize + step * Float(i)
            vertices.append(Vertex(position: SIMD3<Float>(-halfSize, 0, y), color: SIMD4<Float>(0.5, 0.5, 0.5, 1)))
            vertices.append(Vertex(position: SIMD3<Float>(halfSize, 0, y), color: SIMD4<Float>(0.5, 0.5, 0.5, 1)))
            
            if i > 0 {
                let idx = UInt16((i - 1) * 2)
                indices.append(idx)
                indices.append(UInt16(idx + 1))
            }
        }
        
        // Vertical lines
        for i in 0...divisions {
            let x = -halfSize + step * Float(i)
            vertices.append(Vertex(position: SIMD3<Float>(x, 0, -halfSize), color: SIMD4<Float>(0.5, 0.5, 0.5, 1)))
            vertices.append(Vertex(position: SIMD3<Float>(x, 0,  halfSize), color: SIMD4<Float>(0.5, 0.5, 0.5, 1)))
            
            if i > 0 {
                let idx = UInt16((divisions + 1 + i) * 2)
                indices.append(idx)
                indices.append(UInt16(idx + 1))
            }
        }
        
        return (vertices, indices)
    }
}

// MARK: - Export Functions

public func createCubeGeometry() -> ([Vertex], [UInt16]) {
    let (vertices, indices) = GeometryShaders(device: MTLCreateSystemDefaultDevice()!).createCube(), createCubeIndices()
    return (vertices, indices)
}

public func createSphereGeometry(segments: Int = 32) -> ([Vertex], [UInt16]) {
    let geometryShaders = GeometryShaders(device: MTLCreateSystemDefaultDevice()!)
    return geometryShaders.createSphere(segments: segments)
}

public func createPlaneGeometry() -> ([Vertex], [UInt16]) {
    let geometryShaders = GeometryShaders(device: MTLCreateSystemDefaultDevice()!)
    return geometryShaders.createPlane()
}

public func createCylinderGeometry(segments: Int = 16) -> ([Vertex], [UInt16]) {
    let geometryShaders = GeometryShaders(device: MTLCreateSystemDefaultDevice()!)
    return geometryShaders.createCylinder(segments: segments)
}

public func createBoxGeometry(width: Float = 1.0, height: Float = 1.0, depth: Float = 1.0) -> ([Vertex], [UInt16]) {
    let geometryShaders = GeometryShaders(device: MTLCreateSystemDefaultDevice()!)
    return geometryShaders.createBox(width: width, height: height, depth: depth)
}
