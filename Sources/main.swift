import AppKit

// Manual entry point - No SwiftUI App lifecycle
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
