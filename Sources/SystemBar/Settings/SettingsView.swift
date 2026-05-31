import SwiftUI

extension Notification.Name {
    /// Posted when a live-affecting setting (e.g. the global hotkey) changes, so
    /// the ControlItemManager can re-read preferences immediately.
    static let systemBarPreferencesChanged = Notification.Name("SystemBar.preferencesChanged")
}

/// Observable settings model bridging UserDefaults + permissions to SwiftUI.
@MainActor
final class SettingsModel: ObservableObject {
    @Published var startCollapsed: Bool {
        didSet { Preferences.shared.startCollapsed = startCollapsed }
    }
    @Published var launchAtLogin: Bool {
        didSet { LaunchAtLogin.set(launchAtLogin) }
    }
    @Published var useSecondBar: Bool {
        didSet { Preferences.shared.useSecondBar = useSecondBar }
    }
    @Published var hotkeyEnabled: Bool {
        didSet {
            Preferences.shared.hotkeyEnabled = hotkeyEnabled
            NotificationCenter.default.post(name: .systemBarPreferencesChanged, object: nil)
        }
    }
    @Published var autoRehideSeconds: Double {
        didSet { Preferences.shared.autoRehideSeconds = Int(autoRehideSeconds) }
    }
    @Published var hasAccessibility: Bool
    @Published var hasScreenRecording: Bool

    init() {
        startCollapsed = Preferences.shared.startCollapsed
        launchAtLogin = LaunchAtLogin.isEnabled
        useSecondBar = Preferences.shared.useSecondBar
        hotkeyEnabled = Preferences.shared.hotkeyEnabled
        autoRehideSeconds = Double(Preferences.shared.autoRehideSeconds)
        hasAccessibility = MenuBarActivator.hasAccessibility
        hasScreenRecording = ScreenRecordingPermission.isGranted
    }

    func refresh() {
        hasAccessibility = MenuBarActivator.hasAccessibility
        hasScreenRecording = ScreenRecordingPermission.isGranted
    }
}

struct SettingsView: View {
    @StateObject private var model = SettingsModel()

    var body: some View {
        Form {
            Section("Behaviour") {
                Toggle("Auto-collapse icons on launch", isOn: $model.startCollapsed)
                Toggle("Launch SystemBar at login", isOn: $model.launchAtLogin)
                Toggle("Global hotkey (⌥⌘Space)", isOn: $model.hotkeyEnabled)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Auto-collapse again after")
                        Spacer()
                        Text(model.autoRehideSeconds == 0
                             ? "Never"
                             : "\(Int(model.autoRehideSeconds))s")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $model.autoRehideSeconds, in: 0...60, step: 5)
                    Text("Re-hide icons this many seconds after revealing them. 0 = stay revealed until you collapse manually.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle(isOn: $model.useSecondBar) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use pixel-perfect Second Bar")
                        Text("Show hidden icons in a floating panel (notch-safe). Requires Screen Recording. When off, clicking reveals icons in place — no permissions.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                if model.useSecondBar && !model.hasScreenRecording {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Screen Recording not granted — falling back to reveal-in-place. After enabling it in System Settings, quit and reopen SystemBar for it to take effect.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Button("Request…") {
                                ScreenRecordingPermission.request()
                            }
                            Button("Open System Settings") {
                                ScreenRecordingPermission.openSettingsPane()
                            }
                        }
                    }
                }
            } header: {
                Text("Second Bar")
            }

            Section("Permissions") {
                permissionRow(
                    title: "Accessibility",
                    granted: model.hasAccessibility,
                    grantedText: "Granted — clicking icons works.",
                    deniedText: "Needed to click an icon from the Second Bar.",
                    action: { MenuBarActivator.requestAccessibility(); model.refresh() }
                )
                permissionRow(
                    title: "Screen Recording",
                    granted: model.hasScreenRecording,
                    grantedText: "Granted — Second Bar shows real icons.",
                    deniedText: "Optional. Only for the pixel-perfect Second Bar.",
                    action: { ScreenRecordingPermission.request() }
                )
                Button("Refresh permission status") { model.refresh() }
                    .font(.system(size: 11))
            }

            Section("How to pin icons") {
                Text("⌘-drag icons to the **left** of the diagonal divider to hide them when collapsed. Icons kept to the **right** stay always-visible.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 480)
        .onAppear { model.refresh() }
    }

    @ViewBuilder
    private func permissionRow(
        title: String,
        granted: Bool,
        grantedText: String,
        deniedText: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(granted ? grantedText : deniedText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("Grant…", action: action)
            }
        }
    }
}
