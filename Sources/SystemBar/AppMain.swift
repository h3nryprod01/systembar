import AppKit

@main
struct SystemBarMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Accessory: live only in the menu bar, no Dock icon, no main window.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
