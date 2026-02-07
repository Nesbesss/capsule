import AppKit
import Carbon.HIToolbox

class TextPaster {
    private var savedClipboardContent: String?
    
    func paste(text: String) {
        // Check if we are trusted
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("❌ CANNOT PASTE: App is not trusted by Accessibility.")
            return
        }

        // Save current clipboard content
        savedClipboardContent = NSPasteboard.general.string(forType: .string)
        
        // Set our text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        print("📋 Clipboard set to: \"\(text)\"")

        // Increased delay to ensure target app processes clipboard change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.simulatePaste()
            
            // Restore original clipboard after a slightly longer delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.restoreClipboard()
            }
        }
    }
    
    private func simulatePaste() {
        print("⌨️ Simulating Cmd+V event...")
        
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key code for 'V' is 9
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) else {
            print("❌ Failed to create KeyDown event")
            return
        }
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            print("❌ Failed to create KeyUp event")
            return
        }
        
        // Add Command modifier
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        
        // Post the events globally
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        
        print("✅ Cmd+V events posted")
    }
    
    private func restoreClipboard() {
        guard let savedContent = savedClipboardContent else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(savedContent, forType: .string)
        savedClipboardContent = nil
        
        print("📋 Clipboard restored")
    }
}
