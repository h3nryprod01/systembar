import SwiftUI

/// Observable settings model bridging UserDefaults + login item state to SwiftUI.
@MainActor
final class SettingsModel: ObservableObject {
    @Published var startCollapsed: Bool {
        didSet { Preferences.shared.startCollapsed = startCollapsed }
    }
    @Published var launchAtLogin: Bool {
        didSet { LaunchAtLogin.set(launchAtLogin) }
    }
    @Published var hasAccessibility: Bool

    init() {
        startCollapsed = Preferences.shared.startCollapsed
        launchAtLogin = LaunchAtLogin.isEnabled
        hasAccessibility = MenuBarActivator.hasAccessibility
    }

    func refreshAccessibility() {
        hasAccessibility = MenuBarActivator.hasAccessibility
    }
}

struct SettingsView: View {
    @StateObject private var model = SettingsModel()

    var body: some View {
        Form {
            Section("Behaviour") {
                Toggle("Auto-collapse icons on launch", isOn: $model.startCollapsed)
                Toggle("Launch SystemBar at login", isOn: $model.launchAtLogin)
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: model.hasAccessibility ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(model.hasAccessibility ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility")
                            .font(.system(size: 12, weight: .medium))
                        Text(model.hasAccessibility
                             ? "Granted — clicking hidden icons works."
                             : "Needed only to click hidden icons from the Second Bar. No Screen Recording required.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !model.hasAccessibility {
                        Button("Grant…") {
                            MenuBarActivator.requestAccessibility()
                        }
                    }
                }
            }

            Section("How to pin icons") {
                Text("⌘-drag icons to the **left** of the diagonal divider to hide them when collapsed. Icons kept to the **right** stay always-visible.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 380)
        .onAppear { model.refreshAccessibility() }
    }
}
