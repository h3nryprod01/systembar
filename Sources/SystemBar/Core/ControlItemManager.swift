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
    /// Width the divider expands to when collapsing. Measured against Hidden Bar
    /// 1.8, whose divider expands to ~5000pt at runtime — a width bounded to
    /// screenWidth (≈1700 here) is too small to push items off the left edge, so
    /// nothing actually hides. Use a generous multiple of the widest screen.
    private static func collapsedLength(for screen: NSScreen?) -> CGFloat {
        let width = screen?.frame.width ?? NSScreen.main?.frame.width ?? 2000
        return max(5000, width * 3)
    }
    // Expanded width of the divider. 20pt (matching Hidden Bar) so it presents a
    // real, ⌘-draggable target — a 1pt divider is nearly impossible to grab,
    // which blocks arranging it and thus collapsing.
    private static let expandedLength: CGFloat = 20

    private let chevron: NSStatusItem
    private let divider: NSStatusItem
    private lazy var secondBar = SecondBarPanel(
        onActivate: { [weak self] item in self?.activate(item) },
        revealer: self
    )
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
        // Start expanded; collapse a beat later. Following Hidden Bar: at launch
        // the status items aren't position-restored yet, so collapsing has to
        // wait ~1s for autosave to place the divider. We don't gate this on
        // "is anything to the left?" — when collapsed the divider's reported X is
        // garbage (it's 2000+pt wide), which made the old guard skip wrongly.
        divider.length = Self.expandedLength
        if isCollapsed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.applyCollapsed()
            }
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

    /// The primary action for the chevron's left-click and the hotkey: reveal the
    /// hidden icons in place (in the real menu bar), then auto-collapse after the
    /// configured delay. The floating Second Bar is opened separately, from the
    /// right-click menu, so this stays flicker-free.
    func primaryAction() {
        toggle()
    }

    // MARK: - Public actions

    @objc func toggle() {
        // On a secondary display macOS blocks ⌘-drag, so the user can never
        // arrange the divider there and collapsing can't hide anything. Explain
        // that instead of silently doing nothing.
        if !isCollapsed && isOnSecondaryDisplay {
            showExternalDisplayHint()
            return
        }
        // Otherwise collapse/expand directly — like Hidden Bar, we trust the
        // user's ⌘-drag arrangement and don't pre-scan to decide whether to act.
        // (When collapsed, items pushed off-screen report bogus positions, so a
        // "is anything to the left?" gate gives false negatives and wrongly
        // blocks the toggle.) The Setup Guide explains arranging the divider.
        isCollapsed.toggle()
    }

    func collapse() { isCollapsed = true }
    func reveal() { divider.length = Self.expandedLength }


    /// True when SystemBar's controls are on a display that is NOT the macOS
    /// main display (the one that owns the draggable menu bar).
    private var isOnSecondaryDisplay: Bool {
        guard let myScreen = divider.button?.window?.screen,
              let mainScreen = NSScreen.screens.first else { return false }
        return myScreen != mainScreen
    }

    /// Shown when the user tries to collapse on an external display, where macOS
    /// blocks the ⌘-drag arranging that collapsing depends on.
    private func showExternalDisplayHint() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Collapsing isn't available on this display"
        alert.informativeText = """
        macOS only lets you ⌘-drag and arrange menu bar icons on your main \
        display, so SystemBar can't hide icons on a secondary screen.

        Two ways around it:

        • Use the Second Bar here — press \(GlobalHotkey.displayName) (or click the \
        chevron) to see and click every icon. No arranging needed.

        • Or make this screen your main display: System Settings → Displays, then \
        drag the white menu bar onto this screen. Collapsing then works here too.
        """
        alert.addButton(withTitle: "Open Second Bar")
        alert.addButton(withTitle: "Open Display Settings")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if ScreenRecordingPermission.isGranted {
                toggleSecondBar()
            } else {
                ScreenRecordingPermission.request()
            }
        case .alertSecondButtonReturn:
            if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }

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
    /// (The Second Bar's own auto-hide timer is managed inside SecondBarPanel,
    /// because show() is async and the panel only exists after it completes.)
    @objc func toggleSecondBar() {
        secondBar.toggle(anchor: chevron.button?.window?.screen)
    }

    /// Menu action: open the Second Bar, requesting Screen Recording first if it
    /// isn't granted yet (otherwise captured icons would be blank).
    @objc private func openSecondBar() {
        if ScreenRecordingPermission.isGranted {
            toggleSecondBar()
        } else {
            ScreenRecordingPermission.request()
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
        if isCollapsed {
            applyCollapsed()
        } else {
            divider.length = Self.expandedLength
        }
        chevron.button?.image = Icons.chevron(collapsed: isCollapsed)
        chevron.button?.image?.isTemplate = true
    }

    /// Expand the divider to push everything on its left off-screen, sizing it to
    /// the screen the divider currently lives on.
    private func applyCollapsed() {
        let screen = divider.button?.window?.screen
        divider.length = Self.collapsedLength(for: screen)
        chevron.button?.image = Icons.chevron(collapsed: true)
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
        let menu = NSMenu()
        let toggleTitle = isCollapsed ? "Show Icons in Menu Bar" : "Hide Icons in Menu Bar"
        menu.addItem(withTitle: toggleTitle, action: #selector(toggle), keyEquivalent: "")
            .target = self
        // Always offer the Second Bar — it's the way to see ALL icons (incl.
        // hidden Control Center items). If Screen Recording isn't granted yet,
        // opening it will prompt for the permission.
        menu.addItem(withTitle: "Show All Icons", action: #selector(openSecondBar), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Setup Guide…", action: #selector(showOnboarding), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit SystemBar", action: #selector(quit), keyEquivalent: "q")
            .target = self
        // Attach the menu and let the status item open it: macOS then positions it
        // correctly under the bar (the manual popUp(at:) overflowed the top edge,
        // clipping the first item behind a scroll arrow). Detach afterwards so the
        // left-click toggle keeps working.
        chevron.menu = menu
        chevron.button?.performClick(nil)
        chevron.menu = nil
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

// MARK: - ItemRevealing

extension ControlItemManager: ItemRevealing {
    func beginTemporaryReveal() -> Bool {
        guard isCollapsed else { return false }
        divider.length = Self.expandedLength
        return true
    }

    func endTemporaryReveal() {
        divider.length = Self.collapsedLength(for: divider.button?.window?.screen)
    }
}
