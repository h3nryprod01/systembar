import AppKit
import SwiftUI

/// A floating, borderless panel that appears just below the menu bar and lists
/// every status item as a clickable proxy.
///
/// Living in its own window means it is **immune to the notch** — items never get
/// swallowed the way they do when crammed into the real menu bar.
@MainActor
final class SecondBarPanel {
    private var panel: NSPanel?
    private var dismissMonitor: Any?
    private var autoHideTimer: Timer?
    private let onActivate: (MenuBarItem) -> Void

    init(onActivate: @escaping (MenuBarItem) -> Void) {
        self.onActivate = onActivate
    }

    /// Set as soon as a show starts (before the async image capture finishes) so
    /// rapid toggles can't spawn duplicate, untracked panels.
    private var isPresenting = false

    var isVisible: Bool { panel != nil }

    func toggle(anchor screen: NSScreen?) {
        if isVisible || isPresenting {
            hide()
        } else {
            isPresenting = true
            show(anchor: screen)
        }
    }

    func show(anchor screen: NSScreen?) {
        isPresenting = true
        // Never leave an old panel behind — collapse any existing one first.
        hidePanelOnly()

        // Read from the cached snapshot taken while items were visible — we do NOT
        // reveal hidden items here, which is what caused the flash of icons before
        // the panel appeared. The snapshot is refreshed at launch and on every
        // reveal-in-place, so it stays current.
        let snap = MenuBarSnapshot.shared
        let items = snap.items
        let images = snap.images

        let root = SecondBarView(items: items, images: images) { [weak self] item in
            self?.onActivate(item)
            self?.hide()
        }

        let hosting = NSHostingView(rootView: root)
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize

        let panel = makePanel(size: size)
        // Place the SwiftUI content inside the rounded blur background.
        hosting.translatesAutoresizingMaskIntoConstraints = false
        if let container = panel.contentView {
            container.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: container.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }
        position(panel, size: size, on: screen ?? NSScreen.main)
        panel.orderFrontRegardless()
        self.panel = panel
        isPresenting = false
        installDismissMonitor()
        scheduleAutoHide()
    }

    func hide() {
        isPresenting = false
        hidePanelOnly()
    }

    /// Close the panel automatically after the configured idle period.
    private func scheduleAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        let seconds = Preferences.shared.autoRehideSeconds
        guard seconds > 0 else { return }
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds),
                                             repeats: false) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
    }

    /// Tear down the current panel without touching `isPresenting` (used both by
    /// `hide()` and at the start of `show()` to guarantee a single live panel).
    private func hidePanelOnly() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        removeDismissMonitor()
        panel?.orderOut(nil)
        panel = nil
    }

    /// Close the Second Bar when the user clicks anywhere outside it — the panel
    /// is non-activating, so it never resigns key on its own.
    private func installDismissMonitor() {
        dismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            // Any click outside our panel (global monitor only fires for other
            // apps / outside our windows) dismisses it.
            Task { @MainActor in self?.hide() }
        }
    }

    private func removeDismissMonitor() {
        if let dismissMonitor {
            NSEvent.removeMonitor(dismissMonitor)
            self.dismissMonitor = nil
        }
    }

    // MARK: - Window plumbing

    private func makePanel(size: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Dark, rounded background with a hairline border. Menu-bar icons are
        // white template glyphs; captured against the dark bar they only read
        // clearly on a dark surface (a light popover washed them out). The HUD
        // material is dark in both light and dark mode, mirroring the menu bar.
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.appearance = NSAppearance(named: .vibrantDark)
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 1
        effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        panel.contentView = effect
        return panel
    }

    private func position(_ panel: NSPanel, size: NSSize, on screen: NSScreen?) {
        guard let screen = screen else { return }
        let visible = screen.frame
        let margin: CGFloat = 8
        // Top-right corner, just under the menu bar.
        let x = visible.maxX - size.width - margin
        let y = visible.maxY - size.height - (NSStatusBar.system.thickness) - 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
