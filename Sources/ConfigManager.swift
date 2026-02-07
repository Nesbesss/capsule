import Foundation

struct AppConfig: Codable {
    var selectedModel: String = "base.en"
    var dictionary: [String: String] = [:]
    var history: [String] = []
    var totalTranscriptions: Int = 0
    var totalSecondsSaved: Double = 0.0
}

class ConfigManager {
    static let shared = ConfigManager()
    private let fileManager = FileManager.default
    
    private var configURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let capsuleDir = appSupport.appendingPathComponent("Capsule")
        return capsuleDir.appendingPathComponent("config.json")
    }
    
    func loadConfig() -> AppConfig {
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return config
    }
    
    func saveConfig(_ config: AppConfig) {
        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: configURL)
        } catch {
            print("❌ Failed to save config: \(error)")
        }
    }
    
    func watchConfig(onChange: @escaping (AppConfig) -> Void) {
        // Simple polling for now, can be upgraded to FilePresenter
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            onChange(self.loadConfig())
        }
    }
}
