import AppKit
import Combine

class FloatingPillWindow: NSPanel {
    private var appState: AppState
    private var cancellables = Set<AnyCancellable>()
    
    // UI Components
    private let containerView: NSView
    private let iconImageView = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let waveformView = WaveformView(frame: .zero)
    private let logoPath = "/Users/nesbes/capsule/capsule-tauri/src-tauri/icons/Square30x30Logo.png"
    
    private var trackingArea: NSTrackingArea?
    private let dropdownMenu = NSMenu()
    
    init(appState: AppState) {
        self.appState = appState
        
        // Compact pill size
        let pillSize = NSSize(width: 44, height: 44) // Smaller default
        
        // Position bottom-right with padding
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: screenFrame.maxX - pillSize.width - 40,
            y: screenFrame.minY + 40
        )
        
        let contentRect = NSRect(origin: origin, size: pillSize)
        
        self.containerView = NSView(frame: NSRect(origin: .zero, size: pillSize))
        
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Configure panel
        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        
        setupUI(size: pillSize)
        setupBindings()
        setupClickGesture()
        setupTrackingArea()
        setupMenu()
        
        // Set initial state
        updateUI(for: appState.mode)
    }
    
    private func setupUI(size: NSSize) {
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = size.height / 2
        containerView.layer?.masksToBounds = true
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        containerView.layer?.borderWidth = 0.5
        containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        
        // Glass background
        let visualEffect = NSVisualEffectView(frame: containerView.bounds)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]
        containerView.addSubview(visualEffect, positioned: .below, relativeTo: nil)
        
        // Icon (Fixed position on the left)
        iconImageView.frame = NSRect(x: 10, y: (size.height - 24) / 2, width: 24, height: 24)
        if let image = NSImage(contentsOfFile: logoPath) {
            iconImageView.image = image
        } else {
            iconImageView.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Capsule")
        }
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.alphaValue = 0.9
        containerView.addSubview(iconImageView)
        
        // Status Label
        statusLabel.frame = NSRect(x: 48, y: (size.height - 20) / 2, width: 85, height: 20)
        statusLabel.font = .systemFont(ofSize: 12, weight: .semibold) // Slightly bolder for professionalism
        statusLabel.textColor = .white
        statusLabel.alphaValue = 0
        containerView.addSubview(statusLabel)
        
        // Waveform (Increased padding from logo)
        waveformView.frame = NSRect(x: 48, y: 0, width: 85, height: size.height)
        waveformView.alphaValue = 0
        containerView.addSubview(waveformView)
        
        self.contentView = containerView
    }
    
    private func setupTrackingArea() {
        let area = NSTrackingArea(
            rect: containerView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        containerView.addTrackingArea(area)
        self.trackingArea = area
    }
    
    override var canBecomeKey: Bool { return true }

    private func setupMenu() {
        let historyItem = NSMenuItem(title: "History", action: #selector(showHistory), keyEquivalent: "")
        historyItem.target = self
        dropdownMenu.addItem(historyItem)
        
        let dictItem = NSMenuItem(title: "Dictionary", action: #selector(showDictionary), keyEquivalent: "")
        dictItem.target = self
        dropdownMenu.addItem(dictItem)
        
        dropdownMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        dropdownMenu.addItem(quitItem)
    }
    
    override func mouseEntered(with event: NSEvent) {
        // Show indicator or change background to signal hover
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            containerView.animator().layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            containerView.animator().layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        }
    }
    
    @objc private func showHistory() {
        let historyAlert = NSAlert()
        historyAlert.messageText = "Recent Transcriptions"
        let historyText = appState.history.isEmpty ? "No history yet" : appState.history.joined(separator: "\n\n")
        historyAlert.informativeText = historyText
        historyAlert.addButton(withTitle: "Close")
        historyAlert.runModal()
    }
    
    @objc private func showDictionary() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            if appDelegate.dictionaryWindow == nil {
                appDelegate.dictionaryWindow = DictionaryWindow(appState: appState)
            }
            appDelegate.dictionaryWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    private func setupClickGesture() {
        let click = NSClickGestureRecognizer(target: self, action: #selector(pillClicked))
        containerView.addGestureRecognizer(click)
    }
    
    @objc private func pillClicked() {
        let location = NSPoint(x: 0, y: containerView.bounds.height)
        dropdownMenu.popUp(positioning: nil, at: location, in: containerView)
    }
    
    private func showAddWordDialog() {
        let alert = NSAlert()
        alert.messageText = "Add Custom Word Mapping"
        alert.informativeText = "Example: 'open claw' -> 'openclaw'"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        let stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 200, height: 60))
        stackView.orientation = .vertical
        stackView.spacing = 8
        
        let fromField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        fromField.placeholderString = "Spoken phrase (e.g. open claw)"
        
        let toField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        toField.placeholderString = "Replacement (e.g. openclaw)"
        
        stackView.addArrangedSubview(fromField)
        stackView.addArrangedSubview(toField)
        
        alert.accessoryView = stackView
        
        alert.beginSheetModal(for: self) { response in
            if response == .alertFirstButtonReturn {
                let from = fromField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let to = toField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !from.isEmpty && !to.isEmpty {
                    WordDictionary.shared.addMapping(from: from, to: to)
                    Task { @MainActor in
                        self.appState.dictionary = WordDictionary.shared.mappings
                    }
                }
            }
        }
    }
    
    private func setupBindings() {
        appState.$mode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.updateUI(for: mode)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .audioLevelChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let level = notification.userInfo?["level"] as? Float {
                    self?.appState.audioLevel = level
                    if self?.appState.mode == .recording {
                        self?.waveformView.update(level: level)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateUI(for mode: AppMode) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            var newWidth: CGFloat = 44
            
            switch mode {
            case .idle:
                statusLabel.animator().alphaValue = 0
                waveformView.animator().alphaValue = 0
                waveformView.reset()
                iconImageView.animator().alphaValue = 0.8
                containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
                
            case .recording:
                statusLabel.stringValue = ""
                statusLabel.animator().alphaValue = 0
                waveformView.animator().alphaValue = 1
                iconImageView.animator().alphaValue = 1
                newWidth = 140
                containerView.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.5).cgColor
                
            case .processing:
                statusLabel.stringValue = "Processing..."
                statusLabel.animator().alphaValue = 1
                waveformView.animator().alphaValue = 0
                iconImageView.animator().alphaValue = 0.5
                newWidth = 140
                containerView.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.5).cgColor
            }
            
            // Expand/Contract the window frame
            let screenFrame = NSScreen.main?.visibleFrame ?? .zero
            let currentFrame = self.frame
            let newFrame = NSRect(
                x: screenFrame.maxX - newWidth - 40,
                y: currentFrame.origin.y,
                width: newWidth,
                height: currentFrame.size.height
            )
            
            self.animator().setFrame(newFrame, display: true)
        }
    }
}
