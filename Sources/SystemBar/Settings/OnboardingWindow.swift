import AppKit
import SwiftUI

/// First-run setup guide. Explains the one non-obvious step — that macOS makes
/// YOU position the divider with ⌘-drag, because no app may reposition another
/// app's menu-bar icons.
@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: OnboardingView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "SystemBar — Setup Guide"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct OnboardingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to SystemBar")
                .font(.system(size: 20, weight: .bold))
            Text("Three quick things to know:")
                .foregroundStyle(.secondary)

            step("1", "command.square",
                 "Arrange your icons",
                 "Hold ⌘ and drag the icons you want to hide to the LEFT of SystemBar's diagonal divider (╲). Icons kept to the right stay always-visible.")
            step("2", "chevron.left.2",
                 "Collapse & reveal",
                 "Click the chevron (or press \(GlobalHotkey.displayName)) to hide everything left of the divider, and again to show it. macOS only lets an app hide icons this way — it can't reposition them for you, which is why step 1 is manual.")
            step("3", "rectangle.on.rectangle",
                 "Second Bar (optional)",
                 "Turn on the pixel-perfect Second Bar in Settings to see hidden icons in a floating, notch-safe panel. It needs Screen Recording to capture each icon.")

            Spacer()
            Text("You can reopen this guide any time from the right-click menu.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 460, height: 440)
    }

    @ViewBuilder
    private func step(_ n: String, _ symbol: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.15)).frame(width: 30, height: 30)
                Image(systemName: symbol).foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(n). \(title)").font(.system(size: 14, weight: .semibold))
                Text(body).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
