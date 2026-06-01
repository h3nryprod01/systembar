import AppKit
import Carbon.HIToolbox

/// Registers a single global hotkey (⌥⌘Space) via the Carbon Hot Key API.
///
/// Carbon hotkeys need no extra permissions and work system-wide even when
/// SystemBar isn't frontmost — unlike an `NSEvent` global monitor, which would
/// require Accessibility. We keep it to one fixed combo to stay simple.
@MainActor
final class GlobalHotkey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let onFire: () -> Void

    // ⌃⌥⌘B — avoids ⌥⌘Space (Finder search) and other common system combos.
    private static let keyCode = UInt32(kVK_ANSI_B)
    private static let modifiers = UInt32(controlKey | optionKey | cmdKey)
    private static let signature = OSType(0x53594252) // 'SYBR'
    private static let id: UInt32 = 1

    init(onFire: @escaping () -> Void) {
        self.onFire = onFire
    }

    static let displayName = "⌃⌥⌘B"
    var description: String { Self.displayName }

    @discardableResult
    func register() -> Bool {
        guard ref == nil else { return true }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Pass `self` to the C callback via the userData pointer.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData, let event else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if hkID.id == GlobalHotkey.id {
                let me = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in me.onFire() }
            }
            return noErr
        }, 1, &eventType, selfPtr, &handler)

        let hkID = EventHotKeyID(signature: Self.signature, id: Self.id)
        let status = RegisterEventHotKey(Self.keyCode, Self.modifiers,
                                         hkID, GetApplicationEventTarget(), 0, &ref)
        if status != noErr {
            NSLog("SystemBar: hotkey registration failed (status \(status)) for \(description)")
            return false
        }
        return true
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        if let handler { RemoveEventHandler(handler); self.handler = nil }
    }

    func setEnabled(_ enabled: Bool) {
        if enabled { register() } else { unregister() }
    }
    // No deinit cleanup: the single GlobalHotkey lives for the whole app
    // lifetime, and Swift 6 forbids touching these non-Sendable Carbon refs from
    // a nonisolated deinit. Call unregister() explicitly if ever needed.
}
