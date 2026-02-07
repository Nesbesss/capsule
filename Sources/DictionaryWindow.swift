import AppKit
import Combine

class DictionaryWindow: NSPanel {
    private var appState: AppState
    private var cancellables = Set<AnyCancellable>()
    
    // UI Components
    private let containerView: NSVisualEffectView
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let fromField = NSTextField()
    private let toField = NSTextField()
    private let addButton = NSButton()
    
    init(appState: AppState) {
        self.appState = appState
        self.containerView = NSVisualEffectView()
        
        let windowSize = NSSize(width: 400, height: 500)
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let contentRect = NSRect(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY - windowSize.height / 2,
            width: windowSize.width,
            height: windowSize.height
        )
        
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Capsule Dictionary"
        self.isReleasedWhenClosed = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        
        setupUI()
        setupBindings()
    }
    
    private func setupUI() {
        containerView.material = .hudWindow
        containerView.blendingMode = .behindWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 16
        self.contentView = containerView
        
        // Title Label
        let titleLabel = NSTextField(labelWithString: "Dictionary Mappings")
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 20, y: 460, width: 360, height: 24)
        containerView.addSubview(titleLabel)
        
        // ScrollView & TableView
        scrollView.frame = NSRect(x: 20, y: 100, width: 360, height: 350)
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("mapping"))
        column.width = 360
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        containerView.addSubview(scrollView)
        
        // Input Fields (Glassmorphic style)
        fromField.placeholderString = "Spoken Phrase"
        fromField.frame = NSRect(x: 20, y: 60, width: 175, height: 24)
        fromField.bezelStyle = .roundedBezel
        containerView.addSubview(fromField)
        
        toField.placeholderString = "Replacement"
        toField.frame = NSRect(x: 205, y: 60, width: 175, height: 24)
        toField.bezelStyle = .roundedBezel
        containerView.addSubview(toField)
        
        addButton.title = "Add Mapping"
        addButton.bezelStyle = .rounded
        addButton.frame = NSRect(x: 20, y: 20, width: 360, height: 32)
        addButton.target = self
        addButton.action = #selector(addMapping)
        containerView.addSubview(addButton)
    }
    
    private func setupBindings() {
        appState.$dictionary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }
    
    @objc private func addMapping() {
        let from = fromField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = toField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !from.isEmpty && !to.isEmpty {
            WordDictionary.shared.addMapping(from: from, to: to)
            appState.dictionary = WordDictionary.shared.mappings
            fromField.stringValue = ""
            toField.stringValue = ""
        }
    }
}

extension DictionaryWindow: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return appState.dictionary.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let keys = appState.dictionary.keys.sorted()
        let key = keys[row]
        let value = appState.dictionary[key] ?? ""
        
        let container = NSStackView(frame: NSRect(x: 0, y: 0, width: 360, height: 40))
        container.orientation = .horizontal
        container.distribution = .fill
        container.spacing = 10
        container.edgeInsets = NSEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        
        let label = NSTextField(labelWithString: "\(key) → \(value)")
        label.textColor = .white.withAlphaComponent(0.9)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        
        let deleteButton = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")!, target: self, action: #selector(deleteRow(_:)))
        deleteButton.bezelStyle = .inline
        deleteButton.isBordered = false
        deleteButton.tag = row
        
        container.addArrangedSubview(label)
        container.addArrangedSubview(NSView()) // Spacer
        container.addArrangedSubview(deleteButton)
        
        return container
    }
    
    @objc private func deleteRow(_ sender: NSButton) {
        let keys = appState.dictionary.keys.sorted()
        let key = keys[sender.tag]
        WordDictionary.shared.removeMapping(for: key)
        appState.dictionary = WordDictionary.shared.mappings
    }
}
