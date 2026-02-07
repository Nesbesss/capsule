import AVFoundation
import Foundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private let sampleRate: Double = 16000 // Whisper requires 16kHz
    private var isRecording = false
    
    init() {
        checkMicrophonePermission()
    }
    
    private func checkMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("🎤 Microphone access granted")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print(granted ? "🎤 Microphone access granted" : "⚠️ Microphone access denied")
            }
        case .denied, .restricted:
            print("⚠️ Microphone access denied. Please grant access in System Settings.")
        @unknown default:
            break
        }
    }
    
    private let audioQueue = DispatchQueue(label: "com.nesbes.capsule.audio.buffer")
    
    func startRecording() {
        guard !isRecording else { return }
        
        audioQueue.sync {
            audioBuffer.removeAll()
        }
        
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else { return }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Convert to 16kHz mono for Whisper
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else { return }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            print("⚠️ Failed to create audio converter")
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.updateAudioLevel(buffer)
            self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }
        
        do {
            try audioEngine.start()
            isRecording = true
            print("🔴 Recording started")
        } catch {
            print("⚠️ Failed to start audio engine: \(error)")
        }
    }
    
    private func updateAudioLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let length = Int(buffer.frameLength)
        
        var sum: Float = 0
        for i in 0..<length {
            sum += channelData[i] * channelData[i]
        }
        
        let rms = sqrt(sum / Float(length))
        // Normalize and scale for UI (tweak 5.0 for sensitivity)
        let level = min(max(rms * 5.0, 0), 1)
        
        DispatchQueue.main.async {
            // We'll need a way to access appState here, or use a delegate/closure
            // For now, let's assume we can get it or we'll pass it in
            NotificationCenter.default.post(name: .audioLevelChanged, object: nil, userInfo: ["level": level])
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        let frameCount = AVAudioFrameCount(targetFormat.sampleRate * Double(buffer.frameLength) / buffer.format.sampleRate)
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
            return
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let channelData = convertedBuffer.floatChannelData?[0] {
            let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(convertedBuffer.frameLength)))
            
            // Thread-safe append
            audioQueue.async { [weak self] in
                self?.audioBuffer.append(contentsOf: samples)
            }
        }
    }
    
    func stopRecording() -> [Float]? {
        guard isRecording else { return nil }
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        
        var result: [Float]?
        audioQueue.sync {
            print("⏹️ Recording stopped - \(audioBuffer.count) samples")
            if !audioBuffer.isEmpty {
                result = audioBuffer
                audioBuffer.removeAll()
            }
        }
        
        return result
    }
}
