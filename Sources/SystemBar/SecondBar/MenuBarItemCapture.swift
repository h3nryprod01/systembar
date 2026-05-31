import ScreenCaptureKit
import AppKit

/// Captures the real on-screen image of individual menu-bar items using
/// ScreenCaptureKit.
///
/// This is the only way to render an accurate icon for items owned by
/// Control Center (WiFi, Bluetooth, Sound, …) — they all share one process, so
/// the app-icon approach collapses them into identical glyphs. Capturing each
/// item's window content gives the true picture. Requires Screen Recording.
enum MenuBarItemCapture {
    /// Capture an image for each item, keyed by its window id. Items whose
    /// windows can't be matched or captured are simply omitted.
    static func captureImages(for items: [MenuBarItem]) async -> [CGWindowID: NSImage] {
        guard ScreenRecordingPermission.isGranted else { return [:] }

        let content: SCShareableContent
        do {
            // onScreenWindowsOnly: false → also captures items SystemBar has
            // pushed off the left edge while collapsed.
            content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: false
            )
        } catch {
            return [:]
        }

        let windowsByID = Dictionary(
            content.windows.map { ($0.windowID, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let scale = NSScreen.main?.backingScaleFactor ?? 2

        var result: [CGWindowID: NSImage] = [:]
        for item in items {
            guard let scWindow = windowsByID[item.id] else { continue }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            config.width = max(1, Int(scWindow.frame.width * scale))
            config.height = max(1, Int(scWindow.frame.height * scale))
            config.showsCursor = false
            config.ignoreShadowsSingleWindow = true

            do {
                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )
                let size = NSSize(width: scWindow.frame.width, height: scWindow.frame.height)
                result[item.id] = NSImage(cgImage: cgImage, size: size)
            } catch {
                continue
            }
        }
        return result
    }
}
