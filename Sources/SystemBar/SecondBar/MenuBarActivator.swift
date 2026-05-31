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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let current = MenuBarScanner.scan().first { $0.pid == item.pid && $0.ownerName == item.ownerName }
            let target = current ?? item
            postClick(at: target.frame)

            // Re-hide a moment later so the bar stays tidy.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: rehide)
        }
    }

    private static func postClick(at cocoaFrame: CGRect) {
        // Convert Cocoa (bottom-left) center back to CG (top-left) for CGEvent.
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let center = CGPoint(
            x: cocoaFrame.midX,
            y: screenHeight - cocoaFrame.midY
        )

        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                           mouseCursorPosition: center, mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                         mouseCursorPosition: center, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
