import Foundation

/// Thin wrapper over UserDefaults for SystemBar's settings.
@MainActor
final class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let startCollapsed = "SystemBar.startCollapsed"
        static let hasLaunchedBefore = "SystemBar.hasLaunchedBefore"
        static let useSecondBar = "SystemBar.useSecondBar"
        static let hotkeyEnabled = "SystemBar.hotkeyEnabled"
        static let autoRehideSeconds = "SystemBar.autoRehideSeconds"
    }

    private init() {
        defaults.register(defaults: [
            // Auto-collapse on launch — keeping the bar tidy is the whole point.
            // Click the chevron to reveal everything in the Second Bar.
            Key.startCollapsed: true,
            // Default OFF: the pixel-perfect Second Bar needs Screen Recording.
            // Without it we use reveal-in-place, which needs no permissions.
            Key.useSecondBar: false,
            // Global hotkey on by default (⌥⌘Space).
            Key.hotkeyEnabled: true,
            // 0 = never auto-rehide. Otherwise re-collapse after N seconds.
            Key.autoRehideSeconds: 0
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

    /// When true (and Screen Recording is granted), the chevron opens the
    /// pixel-perfect floating Second Bar. When false, the chevron reveals the
    /// real icons in place — no permissions required.
    var useSecondBar: Bool {
        get { defaults.bool(forKey: Key.useSecondBar) }
        set { defaults.set(newValue, forKey: Key.useSecondBar) }
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
