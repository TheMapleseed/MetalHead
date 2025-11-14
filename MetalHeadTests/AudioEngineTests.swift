import XCTest
import AVFoundation
@testable import MetalHeadEngine

/// Unit tests for AudioEngine
final class AudioEngineTests: XCTestCase {
    
    var audioEngine: AudioEngine!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        audioEngine = AudioEngine()
    }
    
    override func tearDownWithError() throws {
        audioEngine = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testAudioEngineInitialization() async throws {
        // Given
        XCTAssertNotNil(audioEngine)
        
        // When - initialize with timeout (AudioEngine can hang without proper setup)
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.audioEngine.initialize()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second timeout
                throw TestError.assertionFailed
            }
            _ = try await group.next()
            group.cancelAll()
        }
        
        // Then
        XCTAssertFalse(audioEngine.isPlaying) // Should not be playing initially
        XCTAssertEqual(audioEngine.volume, 0.5) // Default volume should be 0.5
    }
    
    func testAudioEngineProperties() {
        // Given & When
        let engine = AudioEngine()
        
        // Then
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(engine.volume, 0.5)
        XCTAssertEqual(engine.sampleRate, 44100.0)
        XCTAssertEqual(engine.bufferSize, 1024)
    }
    
    // MARK: - Playback Tests
    
    func testPlayStop() async throws {
        // Given
        try await audioEngine.initialize()
        
        // When
        audioEngine.play()
        
        // Then
        XCTAssertTrue(audioEngine.isPlaying)
        
        // When
        audioEngine.stop()
        
        // Then
        XCTAssertFalse(audioEngine.isPlaying)
    }
    
    func testPauseResume() async throws {
        // Given
        try await audioEngine.initialize()
        audioEngine.play()
        
        // When
        audioEngine.pause()
        
        // Then
        XCTAssertFalse(audioEngine.isPlaying)
        
        // When
        try await audioEngine.resume()
        
        // Then
        XCTAssertTrue(audioEngine.isPlaying)
    }
    
    // MARK: - Volume Control Tests
    
    func testVolumeControl() {
        // Given
        let testVolume: Float = 0.8
        
        // When
        audioEngine.setVolume(testVolume)
        
        // Then
        XCTAssertEqual(audioEngine.volume, testVolume)
    }
    
    func testVolumeClamping() {
        // Given
        let invalidVolume: Float = 1.5
        
        // When
        audioEngine.setVolume(invalidVolume)
        
        // Then
        XCTAssertEqual(audioEngine.volume, 1.0) // Should be clamped to 1.0
    }
    
    func testNegativeVolumeClamping() {
        // Given
        let invalidVolume: Float = -0.5
        
        // When
        audioEngine.setVolume(invalidVolume)
        
        // Then
        XCTAssertEqual(audioEngine.volume, 0.0) // Should be clamped to 0.0
    }
    
    // MARK: - Spatial Audio Tests
    
    func testSpatialPosition() {
        // Given
        let position = SIMD3<Float>(1, 2, 3)
        
        // When & Then (should not crash)
        audioEngine.setSpatialPosition(position)
    }
    
    func testSpatialPositionAtOrigin() {
        // Given
        let position = SIMD3<Float>(0, 0, 0)
        
        // When & Then (should not crash)
        audioEngine.setSpatialPosition(position)
    }
    
    func testSpatialPositionFarAway() {
        // Given
        let position = SIMD3<Float>(100, 100, 100)
        
        // When & Then (should not crash)
        audioEngine.setSpatialPosition(position)
    }
    
    // MARK: - Audio Effects Tests
    
    func testReverbEffect() {
        // Given
        let intensity: Float = 0.5
        
        // When & Then (should not crash)
        audioEngine.applyReverb(intensity: intensity)
    }
    
    func testDelayEffect() {
        // Given
        let time: Float = 0.5
        let feedback: Float = 0.3
        let mix: Float = 0.4
        
        // When & Then (should not crash)
        audioEngine.applyDelay(time: time, feedback: feedback, mix: mix)
    }
    
    // MARK: - Audio Data Tests
    
    func testAudioDataPublisher() {
        // Given
        let publisher = audioEngine.getAudioDataPublisher()
        
        // Then
        XCTAssertNotNil(publisher)
    }
    
    func testSpectrumData() {
        // Given
        let spectrum = audioEngine.getSpectrumData()
        
        // Then
        XCTAssertNotNil(spectrum)
        XCTAssertTrue(spectrum.isEmpty) // Should be empty initially
    }
    
    func testAudioLevel() {
        // Given
        let level = audioEngine.getAudioLevel()
        
        // Then
        XCTAssertEqual(level, 0.0) // Should be 0 initially
    }
    
    // MARK: - Performance Tests
    
    func testAudioProcessingPerformance() async throws {
        // Given
        try await audioEngine.initialize()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When
        for _ in 0..<1000 {
            // Simulate audio processing
            audioEngine.getAudioLevel()
            audioEngine.getSpectrumData()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then
        XCTAssertLessThan(executionTime, 0.1, "Audio processing should be fast")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidAudioFileLoading() async throws {
        // Given
        try await audioEngine.initialize()
        let invalidURL = URL(fileURLWithPath: "/invalid/path/audio.wav")
        
        // When & Then
        do {
            try await audioEngine.loadAudioFile(url: invalidURL)
            XCTFail("Should have thrown an error for invalid file")
        } catch {
            XCTAssertTrue(error is AudioEngineError)
        }
    }
    
    func testInvalidAudioDataLoading() async throws {
        // Given
        try await audioEngine.initialize()
        let invalidData = Data()
        
        // When & Then
        do {
            try await audioEngine.loadAudioFile(data: invalidData, name: "invalid")
            XCTFail("Should have thrown an error for invalid data")
        } catch {
            XCTAssertTrue(error is AudioEngineError)
        }
    }
}
