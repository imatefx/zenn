import Foundation
#if canImport(AppKit)
import AppKit

// Configure as a menu bar app (no Dock icon)
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
#endif
