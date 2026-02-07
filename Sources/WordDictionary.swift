import Foundation

class WordDictionary {
    static let shared = WordDictionary()
    private let storageKey = "com.nesbes.capsule.wordDictionary"
    
    private(set) var mappings: [String: String] = [:] {
        didSet {
            save()
        }
    }
    
    private init() {
        load()
    }
    
    private func load() {
        if let saved = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] {
            mappings = saved
        }
    }
    
    private func save() {
        UserDefaults.standard.set(mappings, forKey: storageKey)
    }
    
    func addMapping(from word: String, to replacement: String) {
        let normalizedWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        mappings[normalizedWord] = replacement
    }
    
    func removeMapping(for word: String) {
        mappings.removeValue(forKey: word.lowercased())
    }
    
    func transform(_ text: String) -> String {
        var transformedText = text
        // Sort keys by length descending to match longer phrases first
        let sortedKeys = mappings.keys.sorted { $0.count > $1.count }
        
        for key in sortedKeys {
            if let replacement = mappings[key] {
                // Use regex for word boundaries to avoid partial matches
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: key))\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    transformedText = regex.stringByReplacingMatches(
                        in: transformedText,
                        options: [],
                        range: NSRange(location: 0, length: transformedText.utf16.count),
                        withTemplate: replacement
                    )
                }
            }
        }
        return transformedText
    }
}
