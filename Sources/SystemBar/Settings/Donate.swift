import AppKit

/// One place for the donation link, so the URL is easy to update before release.
enum Donate {
    /// Update this to your real GitHub Sponsors / Buy Me a Coffee / Ko-fi URL.
    static let url = URL(string: "https://github.com/sponsors/nguyenphucuong")!

    static func open() {
        NSWorkspace.shared.open(url)
    }
}
