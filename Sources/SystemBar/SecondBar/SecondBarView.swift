import SwiftUI

/// The horizontal "Ice-bar" row of menu-bar item proxies shown in the panel.
struct SecondBarView: View {
    let items: [MenuBarItem]
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
                    ItemButton(item: item, onTap: onTap)
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
    let onTap: (MenuBarItem) -> Void
    @State private var hovering = false

    var body: some View {
        Button {
            onTap(item)
        } label: {
            Group {
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 18, height: 18)
                } else {
                    // Fallback: monochrome chip with first letter.
                    Text(String(item.displayName.prefix(1)))
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 18, height: 18)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
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
