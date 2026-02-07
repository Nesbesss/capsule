import AppKit
import SwiftUI

// MARK: - Main Settings Window
class SettingsHub: NSWindow {
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isOpaque = false
        
        // Ensure traffic light buttons are visible
        self.standardWindowButton(.closeButton)?.isHidden = false
        self.standardWindowButton(.miniaturizeButton)?.isHidden = false
        self.standardWindowButton(.zoomButton)?.isHidden = false
        
        self.center()
        
        // Host SwiftUI content
        let swiftUIView = SettingsContentView(appState: appState)
        let hostingView = NSHostingView(rootView: swiftUIView)
        hostingView.frame = self.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        self.contentView?.addSubview(hostingView)
    }
}

// MARK: - SwiftUI Settings View
struct SettingsContentView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab: SettingsTab = .models
    
    enum SettingsTab: String, CaseIterable {
        case models = "Models"
        case dictionary = "Dictionary"
        case history = "History"
        case analytics = "Analytics"
        
        var icon: String {
            switch self {
            case .models: return "cpu"
            case .dictionary: return "book.closed"
            case .history: return "clock"
            case .analytics: return "chart.bar"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Liquid Glass Background
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            
            HStack(spacing: 0) {
                // Sidebar
                sidebarView
                
                // Divider
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1)
                
                // Content
                contentView
            }
        }
        .frame(minWidth: 720, minHeight: 520)
    }
    
    // MARK: - Sidebar
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // App Title
            Text("CAPSULE")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.top, 50)
                .padding(.bottom, 20)
            
            // Tab Buttons
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                SidebarButton(
                    title: tab.rawValue,
                    icon: tab.icon,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }
            }
            
            Spacer()
            
            // Version Badge
            Text("v2.0")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 16)
        .frame(width: 160)
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
        )
    }
    
    // MARK: - Content Area
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text(selectedTab.rawValue)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.top, 40)
                .padding(.horizontal, 32)
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .models:
                        ModelsTabView(appState: appState)
                    case .dictionary:
                        DictionaryTabView(appState: appState)
                    case .history:
                        HistoryTabView(appState: appState)
                    case .analytics:
                        AnalyticsTabView(appState: appState)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sidebar Button
struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .foregroundColor(isSelected ? .accentColor : .primary.opacity(0.75))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Models Tab
struct ModelsTabView: View {
    @ObservedObject var appState: AppState
    
    private let models = [
        ("tiny.en", "Tiny", "Ultra fast, minimal resources"),
        ("base.en", "Base", "Best balance of speed & accuracy"),
        ("small.en", "Small", "High accuracy, more resources")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Speech Recognition Model")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 10) {
                ForEach(models, id: \.0) { id, name, desc in
                    ModelCard(
                        id: id,
                        name: name,
                        description: desc,
                        isSelected: appState.selectedModel == id
                    ) {
                        appState.selectedModel = id
                        appState.saveToConfig()
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchModel"), object: id)
                    }
                }
            }
        }
    }
}

struct ModelCard: View {
    let id: String
    let name: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dictionary Tab
struct DictionaryTabView: View {
    @ObservedObject var appState: AppState
    @State private var showingAddSheet = false
    @State private var newSpoken = ""
    @State private var newReplacement = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Word Mappings")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { showingAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
            }
            
            if appState.dictionary.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No mappings yet")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(appState.dictionary.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        DictionaryRow(spoken: key, replacement: value) {
                            WordDictionary.shared.removeMapping(for: key)
                            appState.dictionary = WordDictionary.shared.mappings
                            appState.saveToConfig()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddMappingSheet(
                spoken: $newSpoken,
                replacement: $newReplacement,
                onAdd: {
                    if !newSpoken.isEmpty && !newReplacement.isEmpty {
                        WordDictionary.shared.addMapping(from: newSpoken, to: newReplacement)
                        appState.dictionary = WordDictionary.shared.mappings
                        appState.saveToConfig()
                        newSpoken = ""
                        newReplacement = ""
                    }
                    showingAddSheet = false
                },
                onCancel: { showingAddSheet = false }
            )
        }
    }
}

struct DictionaryRow: View {
    let spoken: String
    let replacement: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text(spoken)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Text(replacement)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(0.6)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

struct AddMappingSheet: View {
    @Binding var spoken: String
    @Binding var replacement: String
    let onAdd: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Mapping")
                .font(.system(size: 18, weight: .bold))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Spoken Word")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("e.g. 'hello'", text: $spoken)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Replace With")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("e.g. 'hi'", text: $replacement)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Add", action: onAdd)
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}

// MARK: - History Tab
struct HistoryTabView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Transcriptions")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(appState.history.count) items")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            
            if appState.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No transcriptions yet")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("Hold Right Option to start dictating")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(appState.history.enumerated()), id: \.offset) { index, text in
                        HistoryCard(text: text, index: index)
                    }
                }
            }
        }
    }
}

struct HistoryCard: View {
    let text: String
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.5))
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.primary.opacity(0.85))
                .lineLimit(3)
                .textSelection(.enabled)
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

// MARK: - Analytics Tab
struct AnalyticsTabView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Your Statistics")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Transcriptions",
                    value: "\(appState.totalTranscriptions)",
                    icon: "waveform",
                    color: .blue
                )
                
                StatCard(
                    title: "Time Saved",
                    value: String(format: "%.1f min", appState.totalSecondsSaved / 60.0),
                    icon: "clock.arrow.circlepath",
                    color: .green
                )
            }
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Words Mapped",
                    value: "\(appState.dictionary.count)",
                    icon: "text.book.closed",
                    color: .purple
                )
                
                StatCard(
                    title: "Active Model",
                    value: appState.selectedModel.replacingOccurrences(of: ".en", with: "").capitalized,
                    icon: "cpu",
                    color: .orange
                )
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Visual Effect View (NSVisualEffectView wrapper)
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
