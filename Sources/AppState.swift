import Foundation
import Combine

enum AppMode {
    case idle
    case recording
    case processing
}

@MainActor
class AppState: ObservableObject {
    @Published var dictionary: [String: String] = WordDictionary.shared.mappings
    @Published var mode: AppMode = .idle
    @Published var audioLevel: Float = 0.0
    @Published var history: [String] = UserDefaults.standard.stringArray(forKey: "transcriptionHistory") ?? [] {
        didSet {
            UserDefaults.standard.set(history, forKey: "transcriptionHistory")
        }
    }
    @Published var lastTranscription: String = ""
    @Published var errorMessage: String?
    @Published var isAccessibilityGranted: Bool = false
    @Published var isMicrophoneGranted: Bool = false
    
    // v2 Features
    @Published var selectedModel: String = UserDefaults.standard.string(forKey: "selectedModel") ?? "base.en" {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "selectedModel")
        }
    }
    @Published var isModelLoading: Bool = false
    
    // Analytics
    @Published var totalTranscriptions: Int = UserDefaults.standard.integer(forKey: "totalTranscriptions") {
        didSet {
            UserDefaults.standard.set(totalTranscriptions, forKey: "totalTranscriptions")
        }
    }
    @Published var totalSecondsSaved: Double = UserDefaults.standard.double(forKey: "totalSecondsSaved") {
        didSet {
            UserDefaults.standard.set(totalSecondsSaved, forKey: "totalSecondsSaved")
        }
    }
}
