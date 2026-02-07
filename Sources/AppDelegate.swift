import AppKit
import SwiftUI // Only if needed for types, but we are avoiding SwiftUI views

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: FloatingPillWindow?
    var appState: AppState!
    var keyboardMonitor: KeyboardMonitor?
    var audioRecorder: AudioRecorder?
    var transcriptionEngine: TranscriptionEngine?
    var textPaster: TextPaster?
    var dictionaryWindow: DictionaryWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize AppState on Main Thread
        appState = AppState()
        
        // Hide dock icon - we're a floating utility
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize components
        audioRecorder = AudioRecorder()
        transcriptionEngine = TranscriptionEngine()
        textPaster = TextPaster()
        
        // Create floating window
        floatingWindow = FloatingPillWindow(appState: appState)
        floatingWindow?.makeKeyAndOrderFront(nil)
        
        // Set up keyboard monitoring
        keyboardMonitor = KeyboardMonitor(
            onKeyDown: { [weak self] in
                self?.startRecording()
            },
            onKeyUp: { [weak self] in
                self?.stopRecordingAndTranscribe()
            }
        )
        keyboardMonitor?.start()
        
        print("✨ Capsule is ready! Hold Right Option to dictate.")
    }
    
    private func startRecording() {
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.appState.mode == .idle else { return }
            guard let recorder = self.audioRecorder else { return }
            
            self.appState.mode = .recording
            
            // Start recording on background to avoid blocking UI
            DispatchQueue.global(qos: .userInitiated).async {
                recorder.startRecording()
            }
        }
    }
    
    private func stopRecordingAndTranscribe() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.appState.mode == .recording else { return }
            guard let recorder = self.audioRecorder else { return }
            guard let engine = self.transcriptionEngine else { return }
            
            self.appState.mode = .processing
            
            // Stop recording can block, do it on background
            DispatchQueue.global(qos: .userInitiated).async {
                guard let audioBuffer = recorder.stopRecording() else {
                    Task { @MainActor in
                        self.appState.mode = .idle
                    }
                    return
                }
                
                // Transcribe
                Task {
                    do {
                        let text = try await engine.transcribe(audioBuffer: audioBuffer)
                        
                        await MainActor.run {
                            if !text.isEmpty {
                                self.appState.lastTranscription = text
                                self.appState.history.insert(text, at: 0)
                                if self.appState.history.count > 10 {
                                    self.appState.history.removeLast()
                                }
                                self.textPaster?.paste(text: text)
                            }
                            self.appState.mode = .idle
                        }
                    } catch {
                        await MainActor.run {
                            self.appState.errorMessage = error.localizedDescription
                            self.appState.mode = .idle
                        }
                    }
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor?.stop()
    }
}
