import AppKit

/// Caches the menu bar's items and their captured images while they are visible,
/// so the Second Bar can show every icon WITHOUT revealing hidden ones first.
///
/// The reveal-then-capture approach made hidden icons visibly flash on the real
/// menu bar before the panel appeared. Instead we snapshot when the bar is fully
/// expanded (at launch before the first collapse, and on every reveal-in-place),
/// then serve that snapshot when the panel opens — no live reveal, no flicker.
@MainActor
final class MenuBarSnapshot {
    static let shared = MenuBarSnapshot()
    private init() {}

    private(set) var items: [MenuBarItem] = []
    private(set) var images: [CGWindowID: NSImage] = [:]

    /// Capture the current bar (must be called while items are on screen). Merges
    /// new images over old so a partial capture never blanks a known icon.
    func refresh(on screen: NSScreen?) async {
        let scanned = MenuBarScanner.scan(on: screen).filter { $0.frame.minX >= 0 }
        guard !scanned.isEmpty else { return }
        let captured = await MenuBarItemCapture.captureImages(for: scanned)

        items = scanned
        images.merge(captured) { _, new in new }
        // Drop cached images for ids that no longer exist.
        let liveIDs = Set(scanned.map(\.id))
        images = images.filter { liveIDs.contains($0.key) }
    }

    var isEmpty: Bool { items.isEmpty }
}
