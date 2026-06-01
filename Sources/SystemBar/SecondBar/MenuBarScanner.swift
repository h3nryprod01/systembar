import AppKit

/// One menu-bar status item discovered on screen.
struct MenuBarItem: Identifiable {
    let id: CGWindowID
    let pid: pid_t
    let ownerName: String
    let frame: CGRect          // in Cocoa screen coordinates (origin bottom-left)

    var app: NSRunningApplication? {
        NSRunningApplication(processIdentifier: pid)
    }

    var icon: NSImage? {
        app?.icon
    }

    var displayName: String {
        app?.localizedName ?? ownerName
    }
}

/// Enumerates the menu-bar status items currently on screen.
///
/// We read the window list directly (`CGWindowListCopyWindowInfo`) and keep only
/// windows in the status-item layer (`kCGStatusWindowLevel`, == 25). This needs
/// **no special permission at all** — neither Accessibility nor Screen Recording
/// — and gives us each item's owning process and on-screen rectangle.
///
/// Note: items SystemBar has pushed off the left screen edge will report frames
/// with negative / off-screen x, which is how we know they're currently hidden.
enum MenuBarScanner {
    /// Plausible width range for a single status-item icon. Anything wider is the
    /// app-menu region or a layout spacer, not an icon we want to show.
    private static let minIconWidth: CGFloat = 8
    private static let maxIconWidth: CGFloat = 64

    /// Scan menu-bar status items, optionally limited to a single screen.
    ///
    /// With an external display attached there are TWO menu bars, each with its
    /// own status items. `CGWindowListCopyWindowInfo` returns both sets in one
    /// global coordinate space; sorting them purely by X interleaves the two
    /// bars. Passing the screen whose menu bar we're acting on keeps only that
    /// bar's items, so the Second Bar, click-through and collapse logic all
    /// operate on a single, correctly-ordered bar.
    static func scan(on screen: NSScreen? = nil) -> [MenuBarItem] {
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow)) // 25

        // IMPORTANT: do NOT use `.optionOnScreenOnly`. When SystemBar has collapsed
        // the bar, hidden items are pushed off the left screen edge — onscreen-only
        // would exclude exactly the items the Second Bar exists to show. We list
        // all windows and filter to the status-item layer ourselves.
        let options: CGWindowListOption = [.excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        // CGWindow coordinates are global, top-left origin anchored at the main
        // display's top-left. The flip to Cocoa (bottom-left) uses the MAIN
        // screen height; this is correct across all displays because both spaces
        // share that anchor.
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0

        let items: [MenuBarItem] = raw.compactMap { info in
            guard
                let layer = info[kCGWindowLayer as String] as? Int, layer == statusLayer,
                let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { return nil }

            let owner = info[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let windowID = info[kCGWindowNumber as String] as? CGWindowID ?? 0

            // Skip our own control items — they shouldn't list themselves.
            if owner == "SystemBar" { return nil }

            // Keep only things that look like real status-item icons. The status
            // layer also contains wide non-icon windows (the app-menu area,
            // spacers) which would otherwise show up as a big empty gap on the
            // left. A genuine icon is a narrow square-ish window.
            guard bounds.width >= Self.minIconWidth,
                  bounds.width <= Self.maxIconWidth
            else { return nil }

            // CGWindow bounds are top-left origin; flip to Cocoa bottom-left.
            let cocoaFrame = CGRect(
                x: bounds.origin.x,
                y: mainHeight - bounds.origin.y - bounds.height,
                width: bounds.width,
                height: bounds.height
            )

            // Restrict to the target screen's menu bar, when one is given.
            if let screen {
                let center = CGPoint(x: cocoaFrame.midX, y: cocoaFrame.midY)
                guard screen.frame.contains(center) else { return nil }
            }

            return MenuBarItem(id: windowID, pid: pid, ownerName: owner, frame: cocoaFrame)
        }

        // Left-to-right as they appear on the bar.
        return items.sorted { $0.frame.minX < $1.frame.minX }
    }
}
