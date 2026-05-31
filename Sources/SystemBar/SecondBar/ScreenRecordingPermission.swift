import CoreGraphics

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

    /// Ask the system for Screen Recording access. The first call shows the
    /// system prompt; subsequent denials require the user to enable it manually
    /// in System Settings > Privacy & Security > Screen Recording.
    @discardableResult
    static func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}
