import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controlItems: ControlItemManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Startup diagnostic: log what THIS app process actually sees for its
        // permissions (a CLI probe can't tell — it inherits the terminal's TCC).
        let line = "SystemBar startup: screenRecording=\(CGPreflightScreenCaptureAccess()) accessibility=\(AXIsProcessTrusted())\n"
        FileHandle.standardError.write(Data(line.utf8))
        if let url = try? FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("SystemBar-startup.log") {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }

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
