import AppKit
import Combine

class SettingsHub: NSWindow {
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    
    // UI Elements
    private let sidebarWidth: CGFloat = 180
    private let sidebarView = NSVisualEffectView()
    private let settingsContentView = NSView() // Shadow-proof name
    
    enum SettingsTab: String, CaseIterable {
        case models = "Models"
        case dictionary = "Dictionary"
        case history = "History"
        case analytics = "Analytics"
        
        var icon: String {
            switch self {
            case .models: return "cpu"
            case .dictionary: return "book"
            case .history: return "clock"
            case .analytics: return "chart.bar"
            }
        }
    }
    
    init(appState: AppState) {
        self.appState = appState
        
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        super.init(contentRect: NSRect(x: 0, y: 0, width: 800, height: 500), styleMask: styleMask, backing: .buffered, defer: false)
        
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.center()
        
        setupUI()
        switchToTab(.models)
    }
    
    private func setupUI() {
        let container = NSView(frame: self.contentView?.bounds ?? .zero)
        container.autoresizingMask = [.width, .height]
        self.contentView?.addSubview(container)
        
        // Glass Background
        let visualEffect = NSVisualEffectView(frame: container.bounds)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]
        container.addSubview(visualEffect)
        
        // Sidebar
        sidebarView.frame = NSRect(x: 0, y: 0, width: sidebarWidth, height: container.bounds.height)
        sidebarView.material = .sidebar
        sidebarView.blendingMode = .behindWindow
        sidebarView.autoresizingMask = [.height]
        container.addSubview(sidebarView)
        
        setupSidebarContent()
        
        // Separation Line
        let line = NSView(frame: NSRect(x: sidebarWidth, y: 0, width: 1, height: container.bounds.height))
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.separatorColor.cgColor
        line.autoresizingMask = [.height]
        container.addSubview(line)
        
        // Content Area
        settingsContentView.frame = NSRect(x: sidebarWidth + 1, y: 0, width: container.bounds.width - sidebarWidth - 1, height: container.bounds.height)
        settingsContentView.autoresizingMask = [.width, .height]
        container.addSubview(settingsContentView)
    }
    
    private func setupSidebarContent() {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.edgeInsets = NSEdgeInsets(top: 60, left: 12, bottom: 12, right: 12)
        stackView.alignment = .leading
        
        sidebarView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: sidebarView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor)
        ])
        
        // Header in sidebar
        let appName = NSTextField(labelWithString: "CAPSULE")
        appName.font = .systemFont(ofSize: 11, weight: .black)
        appName.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(appName)
        stackView.setCustomSpacing(20, after: appName)
        
        for tab in SettingsTab.allCases {
            let btn = createSidebarButton(for: tab)
            stackView.addArrangedSubview(btn)
        }
    }
    
    private func createSidebarButton(for tab: SettingsTab) -> NSButton {
        let btn = NSButton(title: tab.rawValue, target: self, action: #selector(tabButtonClicked(_:)))
        btn.bezelStyle = .recessed
        btn.isBordered = false
        btn.font = .systemFont(ofSize: 14, weight: .medium)
        btn.alignment = .left
        btn.image = NSImage(systemSymbolName: tab.icon, accessibilityDescription: nil)
        btn.imagePosition = .imageLeft
        btn.setButtonType(.momentaryPushIn)
        btn.identifier = NSUserInterfaceItemIdentifier(tab.rawValue)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return btn
    }
    
    @objc private func tabButtonClicked(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue, let tab = SettingsTab(rawValue: id) else { return }
        switchToTab(tab)
    }
    
    private func switchToTab(_ tab: SettingsTab) {
        // Clear current content
        settingsContentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Add new tab title
        let tabTitle = NSTextField(labelWithString: tab.rawValue)
        tabTitle.font = .systemFont(ofSize: 28, weight: .bold)
        tabTitle.textColor = .labelColor
        tabTitle.translatesAutoresizingMaskIntoConstraints = false
        
        settingsContentView.addSubview(tabTitle)
        NSLayoutConstraint.activate([
            tabTitle.topAnchor.constraint(equalTo: settingsContentView.topAnchor, constant: 40),
            tabTitle.leadingAnchor.constraint(equalTo: settingsContentView.leadingAnchor, constant: 24)
        ])
        
        switch tab {
        case .models: setupModelsTab()
        case .dictionary: setupDictionaryTab()
        case .history: setupHistoryTab()
        case .analytics: setupAnalyticsTab()
        }
    }
    
    private func setupModelsTab() {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 20
        stackView.edgeInsets = NSEdgeInsets(top: 100, left: 24, bottom: 24, right: 24)
        
        settingsContentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: settingsContentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: settingsContentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: settingsContentView.trailingAnchor)
        ])
        
        let models = [
            ("tiny.en", "Ultra Fast - Lightweight usage"),
            ("base.en", "Standard - Best all-around"),
            ("small.en", "Accurate - Better complex words")
        ]
        
        for (id, desc) in models {
            let container = NSStackView()
            container.orientation = .vertical
            container.alignment = .leading
            container.spacing = 2
            
            let btn = NSButton(radioButtonWithTitle: id, target: self, action: #selector(modelSelected(_:)))
            btn.identifier = NSUserInterfaceItemIdentifier(id)
            btn.state = (appState.selectedModel == id) ? .on : .off
            btn.font = .systemFont(ofSize: 15, weight: .semibold)
            
            let descLabel = NSTextField(labelWithString: desc)
            descLabel.font = .systemFont(ofSize: 11)
            descLabel.textColor = .secondaryLabelColor
            
            container.addArrangedSubview(btn)
            container.addArrangedSubview(descLabel)
            stackView.addArrangedSubview(container)
        }
    }
    
    @objc private func modelSelected(_ sender: NSButton) {
        guard let modelId = sender.identifier?.rawValue else { return }
        appState.selectedModel = modelId
        NotificationCenter.default.post(name: NSNotification.Name("SwitchModel"), object: modelId)
    }
    
    private func setupHistoryTab() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        let listStack = NSStackView()
        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 10
        listStack.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.documentView = listStack
        settingsContentView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: settingsContentView.topAnchor, constant: 100),
            scrollView.leadingAnchor.constraint(equalTo: settingsContentView.leadingAnchor, constant: 24),
            scrollView.trailingAnchor.constraint(equalTo: settingsContentView.trailingAnchor, constant: -24),
            scrollView.bottomAnchor.constraint(equalTo: settingsContentView.bottomAnchor, constant: -24),
            listStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        
        if appState.history.isEmpty {
            listStack.addArrangedSubview(NSTextField(labelWithString: "No history yet."))
        } else {
            for item in appState.history {
                let box = createHistoryItem(item)
                listStack.addArrangedSubview(box)
                box.widthAnchor.constraint(equalTo: listStack.widthAnchor).isActive = true
            }
        }
    }
    
    private func createHistoryItem(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.isSelectable = true
        label.isEditable = false
        label.font = .systemFont(ofSize: 13)
        label.cell?.wraps = true
        
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 8
        box.fillColor = NSColor.labelColor.withAlphaComponent(0.04)
        box.borderWidth = 0
        box.contentView = label
        box.contentViewMargins = NSSize(width: 10, height: 10)
        return box
    }
    
    private func setupAnalyticsTab() {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 30
        stackView.edgeInsets = NSEdgeInsets(top: 100, left: 24, bottom: 24, right: 24)
        stackView.alignment = .leading
        
        settingsContentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: settingsContentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: settingsContentView.leadingAnchor)
        ])
        
        let stats = [
            ("TOTAL TRANSCRIPTIONS", "\(appState.totalTranscriptions)"),
            ("ESTIMATED TIME SAVED", String(format: "%.1f minutes", appState.totalSecondsSaved / 60.0))
        ]
        
        for (title, value) in stats {
            let container = NSStackView()
            container.orientation = .vertical
            container.alignment = .leading
            container.spacing = 2
            
            let t = NSTextField(labelWithString: title)
            t.font = .systemFont(ofSize: 10, weight: .bold)
            t.textColor = .secondaryLabelColor
            
            let v = NSTextField(labelWithString: value)
            v.font = .systemFont(ofSize: 36, weight: .bold)
            v.textColor = .labelColor
            
            container.addArrangedSubview(t)
            container.addArrangedSubview(v)
            stackView.addArrangedSubview(container)
        }
    }
    
    private func setupDictionaryTab() {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 16
        stackView.edgeInsets = NSEdgeInsets(top: 100, left: 24, bottom: 24, right: 24)
        stackView.alignment = .leading
        
        settingsContentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: settingsContentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: settingsContentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: settingsContentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: settingsContentView.bottomAnchor)
        ])
        
        let addButton = NSButton(title: "Add New Entry", target: self, action: #selector(addMappingClicked))
        addButton.bezelStyle = .rounded
        stackView.addArrangedSubview(addButton)
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        
        let listStack = NSStackView()
        listStack.orientation = .vertical
        listStack.spacing = 6
        listStack.alignment = .leading
        listStack.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.documentView = listStack
        stackView.addArrangedSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            listStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        
        updateDictionaryList(in: listStack)
    }
    
    private func updateDictionaryList(in stack: NSStackView) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (spoken, replacement) in appState.dictionary.sorted(by: { $0.key < $1.key }) {
            let row = createDictionaryRow(spoken: spoken, replacement: replacement)
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }
    
    private func createDictionaryRow(spoken: String, replacement: String) -> NSView {
        let hStack = NSStackView()
        hStack.spacing = 10
        
        let s = NSTextField(labelWithString: spoken)
        s.font = .systemFont(ofSize: 13, weight: .bold)
        
        let r = NSTextField(labelWithString: "➔ \(replacement)")
        r.textColor = .secondaryLabelColor
        
        let del = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: nil)!, target: self, action: #selector(deleteMappingClicked(_:)))
        del.isBordered = false
        del.identifier = NSUserInterfaceItemIdentifier(spoken)
        
        let spacer = NSView()
        hStack.addArrangedSubview(spacer)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        hStack.addArrangedSubview(del)
        
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 6
        box.fillColor = NSColor.labelColor.withAlphaComponent(0.03)
        box.borderWidth = 0
        box.contentView = hStack
        box.contentViewMargins = NSSize(width: 8, height: 4)
        return box
    }
    
    @objc private func addMappingClicked() {
        let alert = NSAlert()
        alert.messageText = "New Mapping"
        let accessory = NSStackView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        accessory.orientation = .vertical
        let f1 = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        f1.placeholderString = "Spoken"
        let f2 = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        f2.placeholderString = "Replacement"
        accessory.addArrangedSubview(f1)
        accessory.addArrangedSubview(f2)
        alert.accessoryView = accessory
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            WordDictionary.shared.addMapping(from: f1.stringValue, to: f2.stringValue)
            appState.dictionary = WordDictionary.shared.mappings
            switchToTab(.dictionary)
        }
    }
    
    @objc private func deleteMappingClicked(_ sender: NSButton) {
        if let id = sender.identifier?.rawValue {
            WordDictionary.shared.removeMapping(for: id)
            appState.dictionary = WordDictionary.shared.mappings
            switchToTab(.dictionary)
        }
    }
}
