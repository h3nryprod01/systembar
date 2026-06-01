import AppKit

/// Activates the *real* menu-bar item that a Second Bar proxy stands for.
///
/// We can't move another app's status item, so to trigger one that SystemBar has
/// hidden we must briefly bring it back on screen, synthesize a click at its real
/// location, then restore the hidden state.
///
/// Synthesizing a click into another process requires **Accessibility**
/// permission (this is the only place SystemBar needs it — listing items needs
/// nothing). It does NOT require Screen Recording.
@MainActor
enum MenuBarActivator {
    /// Whether we're allowed to post synthetic events to other apps.
    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant Accessibility (opens System Settings pane).
    static func requestAccessibility() {
        // The constant `kAXTrustedCheckOptionPrompt` is a non-Sendable global; its
        // value is the stable string "AXTrustedCheckOptionPrompt".
        let options = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Click the given item at its on-screen location.
    /// - Parameter reveal: called first to make sure hidden items are on screen.
    /// - Parameter rehide: called after a short delay to restore hidden state.
    static func click(_ item: MenuBarItem,
                      reveal: () -> Void,
                      rehide: @escaping @MainActor () -> Void) {
        guard hasAccessibility else {
            requestAccessibility()
            return
        }

        reveal()

        // Give the menu bar a beat to re-lay-out the now-revealed items, then
        // re-scan so we click the item's *current* (revealed) position.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Match by windowID — it is unique and stable. Matching by pid/owner
            // is wrong: every Control Center module shares one process, so that
            // would always resolve to the leftmost item, not the clicked one.
            // Scan all screens (no filter): we match by exact windowID, and the
            // item already carries its true global position.
            let current = MenuBarScanner.scan().first { $0.id == item.id }
            guard let target = current else {
                // Item didn't reappear (e.g. it's a "show when active" module
                // that's currently inactive). Nothing to click; just rehide.
                rehide()
                return
            }
            postClick(at: target.frame, rehide: rehide)
        }
    }

    /// Synthesize a left click at the centre of `cocoaFrame`, restoring the
    /// user's real cursor position afterwards so it doesn't visibly jump and
    /// stay on the menu bar.
    private static func postClick(at cocoaFrame: CGRect,
                                  rehide: @escaping @MainActor () -> Void) {
        // Convert Cocoa (bottom-left) centre back to CG (top-left) for CGEvent.
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let point = CGPoint(x: cocoaFrame.midX, y: screenHeight - cocoaFrame.midY)
        let restore = CGEvent(source: nil)?.location ?? point

        // Move the cursor to the item, then click. A real move first makes the
        // target process register the click reliably.
        warp(to: point)
        post(.leftMouseDown, at: point)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            post(.leftMouseUp, at: point)
            // Put the cursor back where the user left it. The opened menu/popover
            // stays open because the click already landed.
            warp(to: restore)

            // Re-hide a moment later so the bar stays tidy.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: rehide)
        }
    }

    private static func post(_ type: CGEventType, at point: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: type,
                            mouseCursorPosition: point, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }

    private static func warp(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        // Re-couple the hardware mouse to the cursor immediately after warping.
        CGAssociateMouseAndMouseCursorPosition(1)
    }
}
