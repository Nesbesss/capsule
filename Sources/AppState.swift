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
    @Published var history: [String] = []
    @Published var lastTranscription: String = ""
    @Published var errorMessage: String?
    @Published var isAccessibilityGranted: Bool = false
    @Published var isMicrophoneGranted: Bool = false
}
