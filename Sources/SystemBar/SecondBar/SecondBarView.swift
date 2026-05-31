import SwiftUI

/// The horizontal "Ice-bar" row of menu-bar item proxies shown in the panel.
///
/// Each proxy shows the item's real captured image (via ScreenCaptureKit). The
/// panel is only used in the opt-in Screen Recording mode, so a captured image
/// is expected; if one is missing we fall back to a neutral placeholder rather
/// than a misleading app icon.
struct SecondBarView: View {
    let items: [MenuBarItem]
    let images: [CGWindowID: NSImage]
    let onTap: (MenuBarItem) -> Void

    var body: some View {
        HStack(spacing: 6) {
            if items.isEmpty {
                Text("No menu bar items found")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            } else {
                ForEach(items) { item in
                    ItemButton(item: item, image: images[item.id], onTap: onTap)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .fixedSize()
    }
}

private struct ItemButton: View {
    let item: MenuBarItem
    let image: NSImage?
    let onTap: (MenuBarItem) -> Void
    @State private var hovering = false

    var body: some View {
        Button {
            onTap(item)
        } label: {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 20)
                } else {
                    // Neutral placeholder when a capture is unavailable.
                    Image(systemName: "square.dashed")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering ? Color.primary.opacity(0.12) : .clear)
            )
        }
        .buttonStyle(.plain)
        .help(item.displayName)
        .onHover { hovering = $0 }
    }
}
