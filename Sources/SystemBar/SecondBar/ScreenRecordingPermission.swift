import AppKit
import ScreenCaptureKit

/// Screen Recording permission helpers.
///
/// Capturing the *actual* image of another app's status item is impossible
/// without this permission — there is no public API to read a per-item icon
/// otherwise (every Control Center sub-item reports the same owning process).
/// This is why Ice and Bartender both require it for their floating bars.
///
/// SystemBar only needs this for the OPT-IN pixel-perfect Second Bar. The
/// default reveal-in-place mode needs nothing.
enum ScreenRecordingPermission {
    /// Whether the app already has Screen Recording access (no prompt).
    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Ask the system for Screen Recording access.
    ///
    /// `CGRequestScreenCaptureAccess()` is unreliable on recent macOS, so we
    /// instead touch `SCShareableContent`, which is what actually triggers the
    /// system prompt the first time. If access is still missing afterwards we
    /// open the Screen Recording pane in System Settings so the user can enable
    /// it manually. Granting there requires relaunching the app to take effect.
    static func request() {
        // 1) Best-effort legacy call (harmless if it no-ops).
        CGRequestScreenCaptureAccess()

        // 2) Touch SCShareableContent — this reliably surfaces the prompt.
        Task {
            _ = try? await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )
            await MainActor.run {
                if !isGranted { openSettingsPane() }
            }
        }
    }

    /// Open System Settings → Privacy & Security → Screen Recording.
    static func openSettingsPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
