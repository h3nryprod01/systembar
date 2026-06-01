import Foundation

/// Thin wrapper over UserDefaults for SystemBar's settings.
@MainActor
final class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let startCollapsed = "SystemBar.startCollapsed"
        static let hasLaunchedBefore = "SystemBar.hasLaunchedBefore"
        static let hotkeyEnabled = "SystemBar.hotkeyEnabled"
        static let autoRehideSeconds = "SystemBar.autoRehideSeconds"
    }

    private init() {
        defaults.register(defaults: [
            // Auto-collapse on launch — keeping the bar tidy is the whole point.
            Key.startCollapsed: true,
            // Global hotkey on by default (⌃⌥⌘B).
            Key.hotkeyEnabled: true,
            // Re-collapse 10s after revealing in place. 0 = stay revealed.
            Key.autoRehideSeconds: 10
        ])
    }

    var startCollapsed: Bool {
        get { defaults.bool(forKey: Key.startCollapsed) }
        set { defaults.set(newValue, forKey: Key.startCollapsed) }
    }

    var hotkeyEnabled: Bool {
        get { defaults.bool(forKey: Key.hotkeyEnabled) }
        set { defaults.set(newValue, forKey: Key.hotkeyEnabled) }
    }

    /// Seconds of inactivity after revealing before auto-collapsing. 0 disables.
    var autoRehideSeconds: Int {
        get { defaults.integer(forKey: Key.autoRehideSeconds) }
        set { defaults.set(newValue, forKey: Key.autoRehideSeconds) }
    }

    /// First-ever launch: don't surprise the user by hiding their icons before
    /// they've had a chance to arrange them. After the first run, honour their
    /// chosen collapse state.
    var isFirstLaunch: Bool {
        if defaults.bool(forKey: Key.hasLaunchedBefore) { return false }
        defaults.set(true, forKey: Key.hasLaunchedBefore)
        return true
    }
}
