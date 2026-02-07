import AppKit
import SwiftUI // Only if needed for types, but we are avoiding SwiftUI views

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: FloatingPillWindow?
    var appState: AppState!
    var keyboardMonitor: KeyboardMonitor?
    var audioRecorder: AudioRecorder?
    var transcriptionEngine: TranscriptionEngine?
    var textPaster: TextPaster?
    var settingsHub: SettingsHub?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize AppState on Main Thread
        appState = AppState()
        
        // Hide dock icon - we're a floating utility
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize components
        audioRecorder = AudioRecorder()
        transcriptionEngine = TranscriptionEngine(modelName: appState.selectedModel)
        textPaster = TextPaster()
        
        // Create floating window
        floatingWindow = FloatingPillWindow(appState: appState)
        floatingWindow?.makeKeyAndOrderFront(nil)
        
        // Set up settings hub
        settingsHub = SettingsHub(appState: appState)
        
        // Listen for v2 events
        NotificationCenter.default.addObserver(forName: NSNotification.Name("SwitchModel"), object: nil, queue: .main) { [weak self] note in
            if let modelName = note.object as? String {
                self?.transcriptionEngine?.switchModel(to: modelName)
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("OpenSettings"), object: nil, queue: .main) { [weak self] _ in
            self?.settingsHub?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        
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
                                
                                // Update History
                                self.appState.history.insert(text, at: 0)
                                if self.appState.history.count > 50 { // Increased for v2
                                    self.appState.history.removeLast()
                                }
                                
                                // Update Analytics
                                self.appState.totalTranscriptions += 1
                                // Estimate: 150 words per minute, roughly 1 second saved per 2.5 words transcribed
                                let wordCount = text.split(separator: " ").count
                                let secondsSaved = Double(wordCount) / 2.5
                                self.appState.totalSecondsSaved += secondsSaved
                                
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
