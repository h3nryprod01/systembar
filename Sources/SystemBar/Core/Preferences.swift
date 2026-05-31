import Foundation

/// Thin wrapper over UserDefaults for SystemBar's settings.
@MainActor
final class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let startCollapsed = "SystemBar.startCollapsed"
        static let hasLaunchedBefore = "SystemBar.hasLaunchedBefore"
    }

    private init() {
        defaults.register(defaults: [
            // Auto-collapse on launch — keeping the bar tidy is the whole point.
            // Click the chevron to reveal everything in the Second Bar.
            Key.startCollapsed: true
        ])
    }

    var startCollapsed: Bool {
        get { defaults.bool(forKey: Key.startCollapsed) }
        set { defaults.set(newValue, forKey: Key.startCollapsed) }
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
