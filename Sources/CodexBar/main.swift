import AppKit
import CodexBarCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let controller = StatusBarController()
app.run()

_ = controller
