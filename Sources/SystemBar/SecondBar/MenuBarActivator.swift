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
    ///   The caller is responsible for re-collapsing later (e.g. via auto-rehide);
    ///   we deliberately do NOT force a quick re-collapse here, because moving the
    ///   status item dismisses popover-style menus (Notion, etc.) the instant they
    ///   open. NSMenu-style menus (Telegram) survive it, which is why only some
    ///   apps appeared to "flash and vanish".
    static func click(_ item: MenuBarItem, reveal: () -> Void) {
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
            let current = MenuBarScanner.scan().first { $0.id == item.id }
            guard let target = current else { return }
            postClick(at: target.frame)
        }
    }

    /// Synthesize a left click at the centre of `cocoaFrame`. The cursor is left
    /// on the item (not warped back): warping the cursor away can dismiss a
    /// transient popover the moment it opens. The bar re-collapses later via the
    /// owner's auto-rehide timer, by which time the menu/popover is done.
    private static func postClick(at cocoaFrame: CGRect) {
        // Convert Cocoa (bottom-left) centre back to CG (top-left) for CGEvent.
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let point = CGPoint(x: cocoaFrame.midX, y: screenHeight - cocoaFrame.midY)

        warp(to: point)
        post(.leftMouseDown, at: point)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            post(.leftMouseUp, at: point)
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
