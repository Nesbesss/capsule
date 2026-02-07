import Foundation
import Combine

enum AppMode {
    case idle
    case recording
    case processing
}

@MainActor
class AppState: ObservableObject {
    @Published var dictionary: [String: String] = [:]
    @Published var mode: AppMode = .idle
    @Published var audioLevel: Float = 0.0
    @Published var history: [String] = []
    @Published var lastTranscription: String = ""
    @Published var errorMessage: String?
    @Published var isAccessibilityGranted: Bool = false
    @Published var isMicrophoneGranted: Bool = false
    
    // v2 Features
    @Published var selectedModel: String = "base.en"
    @Published var isModelLoading: Bool = false
    
    // Analytics
    @Published var totalTranscriptions: Int = 0
    @Published var totalSecondsSaved: Double = 0.0
    
    init() {
        syncWithConfig()
        
        // Watch for external changes from React/Tauri
        ConfigManager.shared.watchConfig { [weak self] config in
            Task { @MainActor in
                self?.updateFromConfig(config)
            }
        }
    }
    
    func syncWithConfig() {
        let config = ConfigManager.shared.loadConfig()
        updateFromConfig(config)
    }
    
    private func updateFromConfig(_ config: AppConfig) {
        self.dictionary = config.dictionary
        self.history = config.history
        
        // Handle model switch if changed via React UI
        if self.selectedModel != config.selectedModel {
            self.selectedModel = config.selectedModel
            print("🔄 Model change detected in config: \(config.selectedModel)")
            NotificationCenter.default.post(name: NSNotification.Name("SwitchModel"), object: config.selectedModel)
        }
        
        self.totalTranscriptions = config.totalTranscriptions
        self.totalSecondsSaved = config.totalSecondsSaved
        
        // Sync back to WordDictionary for the engine
        WordDictionary.shared.mappings = config.dictionary
    }
    
    func saveToConfig() {
        var config = ConfigManager.shared.loadConfig()
        config.dictionary = self.dictionary
        config.history = self.history
        config.selectedModel = self.selectedModel
        config.totalTranscriptions = self.totalTranscriptions
        config.totalSecondsSaved = self.totalSecondsSaved
        ConfigManager.shared.saveConfig(config)
    }
}
