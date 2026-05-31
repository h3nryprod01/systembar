import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controlItems: ControlItemManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let manager = ControlItemManager()
        manager.install()
        self.controlItems = manager
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Make sure hidden icons are revealed before we exit, otherwise the
        // user's icons would stay pushed off-screen with no way back.
        controlItems?.reveal()
    }
}
