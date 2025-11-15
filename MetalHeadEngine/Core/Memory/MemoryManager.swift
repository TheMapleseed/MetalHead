import Foundation
import Metal
import simd

// MARK: - NSLock Extension (Deprecated - use actor isolation instead)
// Note: This extension is kept for backward compatibility but should not be used in new code
// Use @MainActor or actor types for thread safety in Swift 6
extension NSLock {
    func sync<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

// MARK: - Memory Types

/// Types of memory regions
public enum MemoryRegionType: String, CaseIterable, Sendable {
    case vertex = "vertex"
    case uniform = "uniform"
    case audio = "audio"
    case texture = "texture"
}

/// Memory pool for efficient allocation
public class MemoryPool {
    private let device: MTLDevice
    private var buffers: [MTLBuffer] = []
    private let chunkSize: Int = 1024 * 1024 // 1MB chunks
    private var bufferCache: [String: [MTLBuffer]] = [:]
    
    public init(device: MTLDevice) {
        self.device = device
    }
    
    public func allocateBuffer(size: Int) -> MTLBuffer? {
        guard let buffer = device.makeBuffer(length: max(size, chunkSize), options: [.storageModeShared]) else {
            return nil
        }
        buffers.append(buffer)
        return buffer
    }
    
    public func getBuffer(size: Int, options: MTLResourceOptions, key: String) -> MTLBuffer? {
        // Check cache first
        if let cached = bufferCache[key]?.first(where: { $0.length >= size }) {
            return cached
        }
        
        // Allocate new buffer
        return allocateBuffer(size: size)
    }
    
    public func returnBuffer(_ buffer: MTLBuffer, key: String) {
        if bufferCache[key] == nil {
            bufferCache[key] = []
        }
        bufferCache[key]?.append(buffer)
    }
}

/// Memory region for specific types of allocations
public class MemoryRegion {
    private let pool: MemoryPool
    private let type: MemoryRegionType
    private var allocations: [MemoryRegion.Allocation] = []
    
    // Metrics
    public var capacity: Int = 0
    public var allocatedSize: Int = 0
    public var activeAllocations: Int = 0
    public var freeBlocks: Int = 0
    
    public struct Allocation {
        let offset: Int
        let size: Int
        let buffer: MTLBuffer
        var isFree: Bool = false
        
        var pointer: UnsafeMutableRawPointer {
            return buffer.contents().advanced(by: offset)
        }
    }
    
    public init(pool: MemoryPool, type: MemoryRegionType) {
        self.pool = pool
        self.type = type
    }
    
    public func allocate(size: Int, alignment: Int) -> Allocation {
        // Find or create free space
        if let freeAlloc = allocations.first(where: { $0.isFree && $0.size >= size }) {
            return freeAlloc
        }
        
        // Allocate new buffer
        guard let buffer = pool.allocateBuffer(size: size) else {
            fatalError("Failed to allocate memory buffer")
        }
        
        let allocation = Allocation(
            offset: 0,
            size: size,
            buffer: buffer
        )
        
        allocations.append(allocation)
        
        // Update metrics
        allocatedSize += size
        activeAllocations += 1
        capacity += buffer.length
        
        return allocation
    }
    
    public func deallocate(allocation: Allocation) {
        if let index = allocations.firstIndex(where: { $0.buffer === allocation.buffer && $0.offset == allocation.offset }) {
            allocations[index].isFree = true
            activeAllocations -= 1
            freeBlocks += 1
        }
    }
    
    public func compact() {
        // Remove free allocations
        allocations.removeAll(where: { $0.isFree })
        freeBlocks = 0
    }
    
    public func getReport() -> RegionReport {
        let utilization = capacity > 0 ? Float(allocatedSize) / Float(capacity) : 0.0
        return RegionReport(
            name: type.rawValue.capitalized,
            capacity: capacity,
            allocatedSize: allocatedSize,
            activeAllocations: activeAllocations,
            freeBlocks: freeBlocks,
            utilization: utilization
        )
    }
}

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
    // Note: Removed NSLock - @MainActor provides isolation for all access
    
    // MARK: - Initialization
    public init(device: MTLDevice) {
        self.device = device
        self.memoryPool = MemoryPool(device: device)
        setupMemoryRegions()
    }
    
    // MARK: - Public Interface
    public func allocateVertexData<T>(count: Int, type: T.Type) -> AllocatedMemory<T> {
        // @MainActor isolation ensures thread safety
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
    
    public func allocateUniformData<T>(count: Int, type: T.Type) -> AllocatedMemory<T> {
        // @MainActor isolation ensures thread safety
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
    
    public func allocateAudioData(count: Int) -> AllocatedMemory<Float> {
        // @MainActor isolation ensures thread safety
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
    
    public func allocateTextureData(width: Int, height: Int, bytesPerPixel: Int) -> AllocatedMemory<UInt8> {
        // @MainActor isolation ensures thread safety
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
    
    public func deallocate<T>(_ allocatedMemory: AllocatedMemory<T>) {
        // @MainActor isolation ensures thread safety
        allocatedMemory.region.deallocate(allocation: allocatedMemory.allocation)
        updateMetrics()
    }
    
    public func compactMemory() {
        // @MainActor isolation ensures thread safety
        for (_, region) in memoryRegions {
            region.compact()
        }
        updateMetrics()
    }
    
    public func getMetalBuffer(size: Int, options: MTLResourceOptions) -> MTLBuffer? {
        return memoryPool.getBuffer(size: size, options: options, key: "general")
    }
    
    public func returnMetalBuffer(_ buffer: MTLBuffer) {
        memoryPool.returnBuffer(buffer, key: "general")
    }
    
    public func getMemoryReport() -> MemoryReport {
        // @MainActor isolation ensures thread safety
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
    
    // MARK: - Private Methods
    private func setupMemoryRegions() {
        memoryRegions[.vertex] = MemoryRegion(pool: memoryPool, type: .vertex)
        memoryRegions[.uniform] = MemoryRegion(pool: memoryPool, type: .uniform)
        memoryRegions[.audio] = MemoryRegion(pool: memoryPool, type: .audio)
        memoryRegions[.texture] = MemoryRegion(pool: memoryPool, type: .texture)
    }
    
    private func updateMetrics() {
        totalAllocatedMemory = memoryRegions.values.reduce(0) { $0 + UInt64($1.allocatedSize) }
        activeAllocations = memoryRegions.values.reduce(0) { $0 + $1.activeAllocations }
        
        let totalCapacity = memoryRegions.values.reduce(0) { $0 + $1.capacity }
        memoryFragmentation = totalCapacity > 0 ? Float(totalAllocatedMemory) / Float(totalCapacity) : 0.0
    }
}

// MARK: - Allocated Memory
public struct AllocatedMemory<T> {
    public let pointer: UnsafeMutablePointer<T>
    public let count: Int
    public let region: MemoryRegion
    public let allocation: MemoryRegion.Allocation
    
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
public struct MemoryReport: Sendable {
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
public struct RegionReport: Sendable {
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
