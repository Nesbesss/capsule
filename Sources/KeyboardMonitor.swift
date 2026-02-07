import AppKit
import Carbon.HIToolbox

class KeyboardMonitor {
    private var eventMonitor: Any?
    private var localMonitor: Any?
    private var flagsMonitor: Any?
    private let onKeyDown: () -> Void
    private let onKeyUp: () -> Void
    private var isRightOptionPressed = false
    
    // Right Option key code
    private let rightOptionKeyCode: UInt16 = 61
    
    init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
    }
    
    func start() {
        // Check and request Input Monitoring / Accessibility permission
        let trusted = AXIsProcessTrusted()
        print("🔐 Accessibility trusted: \(trusted)")
        
        if !trusted {
            print("⚠️ Input Monitoring permission required!")
            print("   Go to: System Settings → Privacy & Security → Input Monitoring")
            print("   Add and enable 'Capsule'")
            
            // Prompt user to grant permission
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            
            // Still try to set up monitors - they'll work once permission is granted
        }
        
        // Global monitor for events when app is not active
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        
        // Local monitor for events when app is active  
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
        
        if eventMonitor != nil {
            print("✅ Global keyboard monitor installed")
        } else {
            print("❌ Failed to install global monitor - check Input Monitoring permission")
        }
        
        print("⌨️ Hold Right Option key to start dictation")
    }
    
    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        // Debug: print all flag changes
        print("🎹 Key event: keyCode=\(event.keyCode), flags=\(event.modifierFlags.rawValue)")
        
        // Check if this is the right option key (keyCode 61)
        // Also accept left option (keyCode 58) for easier testing
        let isOptionKey = event.keyCode == 61 || event.keyCode == 58
        guard isOptionKey else { return }
        
        let isPressed = event.modifierFlags.contains(.option)
        
        if isPressed && !isRightOptionPressed {
            // Key just pressed
            isRightOptionPressed = true
            print("🔴 Option key DOWN - starting recording")
            DispatchQueue.main.async { [weak self] in
                self?.onKeyDown()
            }
        } else if !isPressed && isRightOptionPressed {
            // Key just released
            isRightOptionPressed = false
            print("⏹️ Option key UP - stopping recording")
            DispatchQueue.main.async { [weak self] in
                self?.onKeyUp()
            }
        }
    }
}
