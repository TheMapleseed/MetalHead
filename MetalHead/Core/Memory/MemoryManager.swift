import Foundation
import Metal
import simd

/// Core memory management system with dynamic arrays and unified memory optimization
@MainActor
public class MemoryManager: ObservableObject {
    // MARK: - Properties
    @Published public var totalAllocatedMemory: UInt64 = 0
    @Published public var activeAllocations: Int = 0
    @Published public var memoryFragmentation: Float = 0.0
    
    private let device: MTLDevice
    private var memoryPool: MemoryPool
    private var memoryRegions: [MemoryRegionType: MemoryRegion] = [:]
    
    // Thread safety
    private let memoryLock = NSLock()
    
    // MARK: - Initialization
    public init(device: MTLDevice) {
        self.device = device
        self.memoryPool = MemoryPool(device: device)
        setupMemoryRegions()
    }
    
    // MARK: - Public Interface
    public func allocateVertexData<T>(count: Int, type: T.Type) -> AllocatedMemory<T> {
        return memoryLock.sync {
            let size = count * MemoryLayout<T>.stride
            let alignment = max(MemoryLayout<T>.alignment, 16)
            
            let allocation = memoryRegions[.vertex]!.allocate(size: size, alignment: alignment)
            return AllocatedMemory(
                pointer: allocation.pointer.assumingMemoryBound(to: T.self),
                count: count,
                region: memoryRegions[.vertex]!,
                allocation: allocation
            )
        }
    }
    
    public func allocateUniformData<T>(count: Int, type: T.Type) -> AllocatedMemory<T> {
        return memoryLock.sync {
            let size = count * MemoryLayout<T>.stride
            let alignment = max(MemoryLayout<T>.alignment, 256)
            
            let allocation = memoryRegions[.uniform]!.allocate(size: size, alignment: alignment)
            return AllocatedMemory(
                pointer: allocation.pointer.assumingMemoryBound(to: T.self),
                count: count,
                region: memoryRegions[.uniform]!,
                allocation: allocation
            )
        }
    }
    
    public func allocateAudioData(count: Int) -> AllocatedMemory<Float> {
        return memoryLock.sync {
            let size = count * MemoryLayout<Float>.stride
            let alignment = 4
            
            let allocation = memoryRegions[.audio]!.allocate(size: size, alignment: alignment)
            return AllocatedMemory(
                pointer: allocation.pointer.assumingMemoryBound(to: Float.self),
                count: count,
                region: memoryRegions[.audio]!,
                allocation: allocation
            )
        }
    }
    
    public func allocateTextureData(width: Int, height: Int, bytesPerPixel: Int) -> AllocatedMemory<UInt8> {
        return memoryLock.sync {
            let size = width * height * bytesPerPixel
            let alignment = 64
            
            let allocation = memoryRegions[.texture]!.allocate(size: size, alignment: alignment)
            return AllocatedMemory(
                pointer: allocation.pointer.assumingMemoryBound(to: UInt8.self),
                count: size,
                region: memoryRegions[.texture]!,
                allocation: allocation
            )
        }
    }
    
    public func deallocate<T>(_ allocatedMemory: AllocatedMemory<T>) {
        memoryLock.sync {
            allocatedMemory.region.deallocate(allocation: allocatedMemory.allocation)
            updateMetrics()
        }
    }
    
    public func compactMemory() {
        memoryLock.sync {
            for (_, region) in memoryRegions {
                region.compact()
            }
            updateMetrics()
        }
    }
    
    public func getMetalBuffer(size: Int, options: MTLResourceOptions) -> MTLBuffer? {
        return memoryPool.getBuffer(size: size, options: options, key: "general")
    }
    
    public func returnMetalBuffer(_ buffer: MTLBuffer) {
        memoryPool.returnBuffer(buffer, key: "general")
    }
    
    public func getMemoryReport() -> MemoryReport {
        return memoryLock.sync {
            var totalAllocated: UInt64 = 0
            var activeAllocations = 0
            var regionReports: [MemoryRegionType: RegionReport] = [:]
            
            for (type, region) in memoryRegions {
                let report = region.getReport()
                regionReports[type] = report
                totalAllocated += UInt64(report.allocatedSize)
                activeAllocations += report.activeAllocations
            }
            
            let totalCapacity = regionReports.values.reduce(0) { $0 + $1.capacity }
            let fragmentation = totalCapacity > 0 ? Float(totalAllocated) / Float(totalCapacity) : 0.0
            
            return MemoryReport(
                totalAllocated: totalAllocated,
                activeAllocations: activeAllocations,
                fragmentation: fragmentation,
                regionReports: regionReports
            )
        }
    }
    
    // MARK: - Private Methods
    private func setupMemoryRegions() {
        memoryRegions[.vertex] = MemoryRegion(
            name: "VertexData",
            alignment: 16,
            initialSize: 1024 * 1024,
            device: device
        )
        
        memoryRegions[.uniform] = MemoryRegion(
            name: "UniformData",
            alignment: 256,
            initialSize: 64 * 1024,
            device: device
        )
        
        memoryRegions[.audio] = MemoryRegion(
            name: "AudioData",
            alignment: 4,
            initialSize: 512 * 1024,
            device: device
        )
        
        memoryRegions[.texture] = MemoryRegion(
            name: "TextureData",
            alignment: 64,
            initialSize: 4 * 1024 * 1024,
            device: device
        )
    }
    
    private func updateMetrics() {
        totalAllocatedMemory = memoryRegions.values.reduce(0) { $0 + UInt64($1.allocatedSize) }
        activeAllocations = memoryRegions.values.reduce(0) { $0 + $1.activeAllocations }
        
        let totalCapacity = memoryRegions.values.reduce(0) { $0 + $1.capacity }
        memoryFragmentation = totalCapacity > 0 ? Float(totalAllocatedMemory) / Float(totalCapacity) : 0.0
    }
}

// MARK: - Memory Region Types
public enum MemoryRegionType: CaseIterable {
    case vertex
    case uniform
    case audio
    case texture
}

// MARK: - Allocated Memory
public struct AllocatedMemory<T> {
    public let pointer: UnsafeMutablePointer<T>
    public let count: Int
    public let region: MemoryRegion
    public let allocation: MemoryAllocation
    
    public var bufferPointer: UnsafeMutableBufferPointer<T> {
        return UnsafeMutableBufferPointer(start: pointer, count: count)
    }
    
    public subscript(index: Int) -> T {
        get { return pointer[index] }
        set { pointer[index] = newValue }
    }
    
    public func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<T>) throws -> R) rethrows -> R {
        return try body(UnsafeBufferPointer(start: pointer, count: count))
    }
    
    public func withUnsafeMutableBufferPointer<R>(_ body: (UnsafeMutableBufferPointer<T>) throws -> R) rethrows -> R {
        return try body(UnsafeMutableBufferPointer(start: pointer, count: count))
    }
}

// MARK: - Memory Allocation
public struct MemoryAllocation {
    public let offset: Int
    public let size: Int
    public let pointer: UnsafeMutableRawPointer
    
    public init(offset: Int, size: Int, pointer: UnsafeMutableRawPointer) {
        self.offset = offset
        self.size = size
        self.pointer = pointer
    }
}

// MARK: - Memory Report
public struct MemoryReport {
    public let totalAllocated: UInt64
    public let activeAllocations: Int
    public let fragmentation: Float
    public let regionReports: [MemoryRegionType: RegionReport]
    
    public init(totalAllocated: UInt64, activeAllocations: Int, fragmentation: Float, regionReports: [MemoryRegionType: RegionReport]) {
        self.totalAllocated = totalAllocated
        self.activeAllocations = activeAllocations
        self.fragmentation = fragmentation
        self.regionReports = regionReports
    }
}

// MARK: - Region Report
public struct RegionReport {
    public let name: String
    public let capacity: Int
    public let allocatedSize: Int
    public let activeAllocations: Int
    public let freeBlocks: Int
    public let utilization: Float
    
    public init(name: String, capacity: Int, allocatedSize: Int, activeAllocations: Int, freeBlocks: Int, utilization: Float) {
        self.name = name
        self.capacity = capacity
        self.allocatedSize = allocatedSize
        self.activeAllocations = activeAllocations
        self.freeBlocks = freeBlocks
        self.utilization = utilization
    }
}
