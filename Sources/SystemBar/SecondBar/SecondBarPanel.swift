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
    private let onActivate: (MenuBarItem) -> Void

    init(onActivate: @escaping (MenuBarItem) -> Void) {
        self.onActivate = onActivate
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle(anchor screen: NSScreen?) {
        if isVisible {
            hide()
        } else {
            show(anchor: screen)
        }
    }

    func show(anchor screen: NSScreen?) {
        let items = MenuBarScanner.scan()
        let root = SecondBarView(items: items) { [weak self] item in
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
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
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

        // Rounded translucent material background.
        let effect = NSVisualEffectView()
        effect.material = .menu
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        effect.layer?.masksToBounds = true
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
