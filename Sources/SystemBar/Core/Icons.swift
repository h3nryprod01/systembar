import AppKit

/// Small factory for the menu-bar glyphs.
enum Icons {
    static func chevron(collapsed: Bool) -> NSImage? {
        // Collapsed → show a "reveal" affordance; expanded → show "collapse".
        let name = collapsed ? "chevron.left.2" : "chevron.right.2"
        return NSImage(systemSymbolName: name, accessibilityDescription: "SystemBar")
    }
}
