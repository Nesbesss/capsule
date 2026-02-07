import Foundation
import WhisperKit

class TranscriptionEngine {
    private var whisperKit: WhisperKit?
    private var isInitialized = false
    
    init() {
        Task {
            await initializeWhisper()
        }
    }
    
    private func initializeWhisper() async {
        do {
            // Initialize WhisperKit with base.en model for better accuracy while maintaining speed
            whisperKit = try await WhisperKit(
                model: "base.en",
                verbose: false,
                logLevel: .none
            )
            isInitialized = true
            print("🧠 Whisper model loaded (base.en)")
        } catch {
            print("⚠️ Failed to initialize Whisper: \(error)")
        }
    }
    
    func transcribe(audioBuffer: [Float]) async throws -> String {
        // Wait for initialization if needed
        while !isInitialized {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        guard let whisperKit = whisperKit else {
            throw TranscriptionError.notInitialized
        }
        
        print("🎯 Transcribing \(audioBuffer.count) samples...")
        
        // Transcribe the audio buffer
        let results = try await whisperKit.transcribe(audioArray: audioBuffer)
        
        // Extract text from results
        let rawText = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Apply dictionary mappings
        let text = WordDictionary.shared.transform(rawText)
        
        print("✅ Raw: \"\(rawText)\"")
        print("✅ Transformed: \"\(text)\"")
        return text
    }
}

enum TranscriptionError: Error, LocalizedError {
    case notInitialized
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Whisper model not initialized"
        case .transcriptionFailed:
            return "Transcription failed"
        }
    }
}
