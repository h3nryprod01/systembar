import AppKit

/// One place for the donation link, so the URL is easy to update before release.
enum Donate {
    /// Donation link. PayPal.me works well for VN — no Stripe/GitHub Sponsors needed.
    static let url = URL(string: "https://paypal.me/CuongNguyen557")!

    static func open() {
        NSWorkspace.shared.open(url)
    }
}
