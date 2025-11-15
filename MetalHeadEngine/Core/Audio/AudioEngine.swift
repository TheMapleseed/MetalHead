import AVFoundation
import AudioToolbox
import Accelerate
import Foundation
import Combine

/// Core audio engine with real-time processing and 3D spatial audio
@MainActor
public class AudioEngine: ObservableObject {
    // MARK: - Properties
    @Published public var isPlaying: Bool = false
    @Published public var volume: Float = 0.5
    @Published public var sampleRate: Double = 44100.0
    @Published public var bufferSize: UInt32 = 1024
    
    // Audio components
    private var audioEngine: AVAudioEngine!
    private var audioPlayerNode: AVAudioPlayerNode!
    private var audioMixer: AVAudioMixerNode!
    private var audioFormat: AVAudioFormat!
    
    // Real-time audio processing
    private var audioBuffer: [Float] = []
    private var fftBuffer: [Float] = []
    // Note: nonisolated(unsafe) is safe here because fftSetup is only written during initialization
    // and only read from nonisolated real-time methods after initialization
    nonisolated(unsafe) private var fftSetup: FFTSetup?
    private var audioDataPublisher = PassthroughSubject<[Float], Never>()
    
    // Audio visualization data
    @Published public var audioSpectrum: [Float] = []
    @Published public var audioLevel: Float = 0.0
    
    // Audio sources
    private var audioFiles: [String: AVAudioFile] = [:]
    private var currentAudioFile: AVAudioFile?
    
    // Concurrency
    // Note: Removed DispatchQueue - use Task with proper actor isolation instead
    private var audioTimer: Timer?
    
    // MARK: - Initialization
    public init() {
        setupAudioSession()
    }
    
    // MARK: - Public Interface
    public func initialize() async throws {
        // Audio engine initialization - make it non-blocking
        // If audio fails, we should still be able to render
        do {
        try await setupAudioEngine()
        try await setupFFT()
        print("Audio Engine initialized successfully")
        } catch {
            print("⚠️ Audio Engine initialization failed (non-critical): \(error)")
            // Don't throw - audio is optional for rendering
        }
    }
    
    public func play() {
        guard !isPlaying else { return }
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            if let audioFile = self.currentAudioFile {
                // Note: scheduleSegment is synchronous and deprecated, but there's no async alternative yet
                _ = {
                    self.audioPlayerNode.scheduleSegment(
                        audioFile,
                        startingFrame: 0,
                        frameCount: AVAudioFrameCount(audioFile.length),
                        at: nil
                    )
                }()
            } else {
                self.generateTestTone()
            }
            
            self.audioPlayerNode.play()
            self.isPlaying = true
        }
    }
    
    public func stop() {
        guard isPlaying else { return }
        
        Task { @MainActor [weak self] in
            self?.audioPlayerNode.stop()
            self?.isPlaying = false
        }
    }
    
    public func pause() {
        audioPlayerNode.pause()
        isPlaying = false
    }
    
    public func resume() {
        audioPlayerNode.play()
        isPlaying = true
    }
    
    public func loadAudioFile(url: URL) async throws {
        let audioFile = try AVAudioFile(forReading: url)
        audioFiles[url.lastPathComponent] = audioFile
        currentAudioFile = audioFile
    }
    
    public func loadAudioFile(data: Data, name: String) async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).wav")
        try data.write(to: tempURL)
        
        let audioFile = try AVAudioFile(forReading: tempURL)
        audioFiles[name] = audioFile
        currentAudioFile = audioFile
        
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    public func setVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        self.volume = clampedVolume
        audioPlayerNode.volume = clampedVolume
    }
    
    public func applyReverb(intensity: Float) {
        let reverb = AVAudioUnitReverb()
        reverb.wetDryMix = intensity * 100
        reverb.loadFactoryPreset(.mediumHall)
        
        audioEngine.attach(reverb)
        audioEngine.connect(audioPlayerNode, to: reverb, format: audioFormat)
        audioEngine.connect(reverb, to: audioMixer, format: audioFormat)
    }
    
    public func applyDelay(time: Float, feedback: Float, mix: Float) {
        let delay = AVAudioUnitDelay()
        delay.delayTime = TimeInterval(time)
        delay.feedback = feedback
        delay.wetDryMix = mix * 100
        
        audioEngine.attach(delay)
        audioEngine.connect(audioPlayerNode, to: delay, format: audioFormat)
        audioEngine.connect(delay, to: audioMixer, format: audioFormat)
    }
    
    public func setSpatialPosition(_ position: SIMD3<Float>) {
        let distance = length(position)
        let azimuth = atan2(position.x, position.z)
        _ = atan2(position.y, sqrt(position.x * position.x + position.z * position.z))
        
        let volumeAttenuation = 1.0 / (1.0 + distance * 0.1)
        setVolume(volume * volumeAttenuation)
        
        let pan = sin(azimuth) * 0.5 + 0.5
        audioPlayerNode.pan = pan
    }
    
    public func getAudioDataPublisher() -> AnyPublisher<[Float], Never> {
        return audioDataPublisher.eraseToAnyPublisher()
    }
    
    public func getSpectrumData() -> [Float] {
        return audioSpectrum
    }
    
    public func getAudioLevel() -> Float {
        return audioLevel
    }
    
    // MARK: - Private Methods
    private func setupAudioSession() {
        // AVAudioSession not available on macOS
        // On macOS, audio routing is handled by Core Audio and HAL
    }
    
    private func setupAudioEngine() async throws {
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        audioMixer = audioEngine.mainMixerNode
        
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
        
        audioEngine.attach(audioPlayerNode)
        audioEngine.connect(audioPlayerNode, to: audioMixer, format: audioFormat)
        
        setupRealTimeProcessing()
        try audioEngine.start()
    }
    
    private func setupRealTimeProcessing() {
        // Note: Audio tap callback runs on audio thread (RealtimeMessenger.mServiceQueue), not main actor
        // The closure must be @Sendable and only do real-time-safe work
        // All @MainActor updates must be deferred via Task { @MainActor in }
        audioMixer.installTap(onBus: 0, bufferSize: bufferSize, format: audioFormat) { @Sendable [weak self] buffer, time in
            guard let self = self else { return }
            
            // Real-time safe processing only - no @MainActor access here
            // Extract audio data on the audio thread
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            let audioData = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
            
            // Compute level and FFT on audio thread (real-time safe)
            let level = self.computeAudioLevelRealtime(audioData)
            let spectrum = self.computeFFTRealtime(audioData)
            
            // Defer all @MainActor updates off the real-time queue
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.audioBuffer = audioData
                self.audioLevel = level
                self.audioSpectrum = spectrum
                self.audioDataPublisher.send(audioData)
            }
        }
    }
    
    private func setupFFT() async throws {
        let log2n = vDSP_Length(log2(Double(bufferSize)))
        fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))
        
        fftBuffer = Array(repeating: 0.0, count: Int(bufferSize))
        audioSpectrum = Array(repeating: 0.0, count: Int(bufferSize / 2))
    }
    
    // Real-time safe computation - nonisolated to allow calling from audio thread
    // Note: This method is called from the audio tap closure which runs on a real-time thread
    nonisolated private func computeAudioLevelRealtime(_ audioData: [Float]) -> Float {
        var rms: Float = 0.0
        vDSP_rmsqv(audioData, 1, &rms, vDSP_Length(audioData.count))
        return rms
    }
    
    // Real-time safe FFT computation - nonisolated to allow calling from audio thread
    // Note: fftSetup is accessed via nonisolated(unsafe) since it's only read after initialization
    // and FFT operations are thread-safe for read-only access
    nonisolated private func computeFFTRealtime(_ audioData: [Float]) -> [Float] {
        // Access fftSetup safely - it's initialized before the tap is installed
        // and only read from here, so it's safe to access from nonisolated context
        guard let fftSetup = self.fftSetup else { return [] }
        
        let halfSize = audioData.count / 2
        var realParts = Array(audioData.prefix(halfSize))
        var imaginaryParts = Array(repeating: Float(0.0), count: halfSize)
        
        var dbMagnitudes = Array(repeating: Float(0.0), count: halfSize)
        
        realParts.withUnsafeMutableBufferPointer { realBuffer in
            imaginaryParts.withUnsafeMutableBufferPointer { imagBuffer in
                var splitComplex = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imagBuffer.baseAddress!)
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Double(halfSize))), Int32(FFT_FORWARD))
                
                var magnitudes = Array(repeating: Float(0.0), count: halfSize)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))
                
                var refValue = Float(1.0)
                vDSP_vdbcon(magnitudes, 1, &refValue, &dbMagnitudes, 1, vDSP_Length(halfSize), 1)
            }
        }
        
        return Array(dbMagnitudes.prefix(min(64, halfSize)))
    }
    
    private func generateTestTone() {
        let duration: Float = 1.0
        let frequency: Float = 440.0
        let sampleRate = Float(self.sampleRate)
        let frameCount = UInt32(sampleRate * duration)
        
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        for i in 0..<Int(frameCount) {
            let sample = sin(2.0 * Float.pi * frequency * Float(i) / sampleRate) * 0.3
            channelData[i] = sample
        }
        
        audioPlayerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
    }
    
    // MARK: - Cleanup
    deinit {
        // Cleanup handled by system - cannot access non-Sendable properties from deinit
    }
}

// MARK: - Errors
public enum AudioEngineError: Error, Sendable {
    case engineStartFailed
    case fileLoadFailed
    case recordingFailed
    case fftSetupFailed
}
