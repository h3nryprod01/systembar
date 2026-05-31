import AppKit

/// Owns the status-bar items SystemBar adds to the menu bar and implements the
/// collapse / reveal behaviour.
///
/// macOS gives no public API to hide another app's status item. The only
/// technique that works (and the one Bartender / Ice / Hidden Bar all use) is
/// the "expanding separator" trick:
///
/// The menu bar lays items out right-to-left. We add our own `divider` status
/// item. When we set its `length` to a very large value it consumes the whole
/// bar and pushes every item to its LEFT off the left edge of the screen — they
/// become invisible. Shrinking the divider lets them slide back into view.
///
/// The user decides which icons get hidden by ⌘-dragging them to the LEFT of
/// our divider. Icons kept to the RIGHT of the divider stay always-visible.
///
/// Layout (left → right):
///   [ … icons that collapse … ] [divider] [ … pinned icons … ] [chevron]
@MainActor
final class ControlItemManager {
    /// Width the divider expands to when collapsing. Large enough to shove the
    /// hidden section past the left screen edge on any display.
    private static let collapsedLength: CGFloat = 10_000
    private static let expandedLength: CGFloat = 1

    private let chevron: NSStatusItem
    private let divider: NSStatusItem
    private lazy var secondBar = SecondBarPanel { [weak self] item in
        self?.activate(item)
    }
    private let settings = SettingsWindowController()
    private let onboarding = OnboardingWindowController()
    private lazy var hotkey = GlobalHotkey { [weak self] in self?.primaryAction() }
    private var rehideTimer: Timer?

    // Runtime collapse state. This is intentionally NOT persisted on every
    // toggle: `Preferences.startCollapsed` is a *launch* preference (what state
    // to start in), separate from the live state. Writing it on every reveal was
    // the bug that stopped the bar from auto-collapsing on the next launch.
    //
    // On the very first launch start expanded so the user can see their icons
    // (and our divider) and arrange them before anything gets hidden.
    private var isCollapsed: Bool = Preferences.shared.isFirstLaunch
        ? false
        : Preferences.shared.startCollapsed {
        didSet { applyState(); scheduleAutoRehide() }
    }

    init() {
        // The clickable control. Sits to the right of the pinned section.
        chevron = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // The expanding separator that does the hiding.
        divider = NSStatusBar.system.statusItem(withLength: Self.expandedLength)

        // Persist the user's ⌘-drag ordering across launches.
        chevron.autosaveName = "SystemBar.chevron"
        divider.autosaveName = "SystemBar.divider"
    }

    func install() {
        configureChevron()
        configureDivider()
        applyState()
        // Re-apply collapse shortly after launch: at didFinishLaunching the menu
        // bar isn't fully laid out yet, so an immediate length change can be
        // ignored. This makes auto-collapse-on-launch actually stick.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.applyState()
        }
        hotkey.setEnabled(Preferences.shared.hotkeyEnabled)
        NotificationCenter.default.addObserver(
            forName: .systemBarPreferencesChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshFromPreferences() }
        }
        if Preferences.shared.isFirstLaunch {
            onboarding.show()
        }
    }

    /// Re-read settings that affect live behaviour (called when Settings change).
    func refreshFromPreferences() {
        hotkey.setEnabled(Preferences.shared.hotkeyEnabled)
    }

    /// The primary toggle, shared by the chevron's left-click and the hotkey.
    func primaryAction() {
        if Preferences.shared.useSecondBar {
            if ScreenRecordingPermission.isGranted {
                toggleSecondBar()
            } else {
                ScreenRecordingPermission.request()
            }
        } else {
            toggle()
        }
    }

    // MARK: - Public actions

    @objc func toggle() { isCollapsed.toggle() }
    func collapse() { isCollapsed = true }
    func reveal() { divider.length = Self.expandedLength }

    /// Re-apply whatever collapse state the user has chosen (used after a
    /// temporary reveal for clicking a hidden item).
    func restoreCollapseState() { applyState() }

    /// If auto-rehide is enabled and we're currently revealed, schedule a
    /// re-collapse after the configured idle period.
    private func scheduleAutoRehide() {
        rehideTimer?.invalidate()
        rehideTimer = nil
        let seconds = Preferences.shared.autoRehideSeconds
        guard seconds > 0, !isCollapsed else { return }
        rehideTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds),
                                           repeats: false) { [weak self] _ in
            Task { @MainActor in self?.collapse() }
        }
    }

    /// Open/close the floating Second Bar that lists every menu-bar item.
    @objc func toggleSecondBar() {
        secondBar.toggle(anchor: chevron.button?.window?.screen)
        // Auto-rehide also applies to the Second Bar: if it's now open, schedule
        // it to close after the idle period.
        scheduleSecondBarAutoHide()
    }

    /// Close the Second Bar automatically after the configured idle period.
    private func scheduleSecondBarAutoHide() {
        rehideTimer?.invalidate()
        rehideTimer = nil
        let seconds = Preferences.shared.autoRehideSeconds
        guard seconds > 0, secondBar.isVisible else { return }
        rehideTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds),
                                           repeats: false) { [weak self] _ in
            Task { @MainActor in self?.secondBar.hide() }
        }
    }

    /// Activate the real item a Second Bar proxy stands for: reveal it, click it,
    /// then restore the collapsed state.
    private func activate(_ item: MenuBarItem) {
        MenuBarActivator.click(
            item,
            reveal: { [weak self] in self?.reveal() },
            rehide: { [weak self] in self?.restoreCollapseState() }
        )
    }

    // MARK: - Configuration

    private func configureChevron() {
        guard let button = chevron.button else { return }
        button.image = Icons.chevron(collapsed: isCollapsed)
        button.image?.isTemplate = true
        button.target = self
        button.action = #selector(chevronClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "SystemBar — click to show/hide menu bar icons (right-click for menu)"
    }

    private func configureDivider() {
        guard let button = divider.button else { return }
        let sep = NSImage(systemSymbolName: "line.diagonal", accessibilityDescription: "divider")
        button.image = sep
        button.image?.isTemplate = true
        button.appearsDisabled = true
        button.toolTip = "SystemBar divider — ⌘-drag icons to the LEFT to hide them"
    }

    private func applyState() {
        divider.length = isCollapsed ? Self.collapsedLength : Self.expandedLength
        chevron.button?.image = Icons.chevron(collapsed: isCollapsed)
        chevron.button?.image?.isTemplate = true
    }

    // MARK: - Events

    @objc private func chevronClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showMenu()
            return
        }
        primaryAction()
    }

    private func showMenu() {
        guard let button = chevron.button else { return }
        let menu = NSMenu()
        let toggleTitle = isCollapsed ? "Show Icons in Menu Bar" : "Hide Icons in Menu Bar"
        menu.addItem(withTitle: toggleTitle, action: #selector(toggle), keyEquivalent: "")
            .target = self
        if ScreenRecordingPermission.isGranted {
            menu.addItem(withTitle: "Open Second Bar", action: #selector(toggleSecondBar), keyEquivalent: "")
                .target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Setup Guide…", action: #selector(showOnboarding), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit SystemBar", action: #selector(quit), keyEquivalent: "q")
            .target = self
        // Pop up just below the chevron without hijacking the left-click action.
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: button.bounds.height + 4),
                   in: button)
    }

    @objc private func openSettings() {
        settings.show()
    }

    @objc private func showOnboarding() {
        onboarding.show()
    }

    @objc private func quit() {
        reveal()
        NSApp.terminate(nil)
    }
}
