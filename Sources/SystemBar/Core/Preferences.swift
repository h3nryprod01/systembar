import Foundation

/// Thin wrapper over UserDefaults for SystemBar's settings.
@MainActor
final class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let startCollapsed = "SystemBar.startCollapsed"
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
}
