# SystemBar

A tidy menu-bar manager for macOS — collapse the clutter, pin the icons you
always want, and reveal hidden ones in a notch-safe floating bar. Built because
Bartender (closed-source, changed ownership) and Hidden Bar fell short on the
notch and on per-icon pinning.

## Two modes

| Mode | Permissions | What clicking the chevron does |
|---|---|---|
| Reveal-in-place (default) | none | Temporarily expands the divider so the real icons slide back onto the menu bar |
| Pixel-perfect Second Bar (opt-in) | Screen Recording (+ Accessibility to click) | Opens a floating panel showing every hidden icon, captured for real — notch-safe |

Why the Second Bar needs Screen Recording: macOS has no API to read a per-item
menu-bar icon. Every Control Center module (WiFi, Bluetooth, Sound, …) is owned
by one process, so an app-icon approach renders them as identical glyphs. The
only way to show the true icon is to capture each item's window image — which is
exactly what Ice and Bartender do, and why they require the same permission.
SystemBar keeps it strictly opt-in.

## Status

- [x] Collapse / reveal via expanding-separator (0 permissions)
- [x] Right-click menu: Show/Hide, Open Second Bar, Settings, Quit
- [x] Pixel-perfect Second Bar via ScreenCaptureKit (per-window capture, notch-safe)
- [x] Click an item -> reveal + click the real icon (Accessibility)
- [x] Dismiss Second Bar on outside click; expand on first launch
- [x] Settings: auto-collapse, launch at login, Second Bar toggle, permission status
- [x] Launch at login (SMAppService)
- [ ] Pin individual icons via UI (today: Cmd-drag relative to divider)
- [ ] Global hotkey to summon the Second Bar
- [ ] Composite single-shot capture (Ice-style) for fewer SCK calls

## Build & run

    ./scripts/bundle.sh                       # -> build/SystemBar.app
    open build/SystemBar.app

Rebuild & relaunch:

    ./scripts/bundle.sh && osascript -e 'tell application "SystemBar" to quit'; open build/SystemBar.app

## Interaction

- Left-click chevron  -> reveal icons (in place, or Second Bar if enabled + permitted)
- Right-click chevron -> menu (Show/Hide, Second Bar, Settings, Quit)
- Cmd-drag icons left/right of the diagonal divider to choose what hides

## How collapsing works

macOS has no public API to hide another app's menu-bar icon. The only working
technique (used by Bartender / Ice / Hidden Bar) is the expanding separator:
SystemBar adds a divider status item; you Cmd-drag icons to its left to mark
them hidden; collapsing expands the divider so it pushes them off the screen
edge. Icons kept to the right stay always-visible (your pins).

## Architecture

    Sources/SystemBar/
      Core/      ControlItemManager (collapse/reveal, chevron, menu), Preferences, Icons
      SecondBar/ MenuBarScanner (CGWindowList, no perms), MenuBarItemCapture (SCK),
                 ScreenRecordingPermission, MenuBarActivator (click-through, AX),
                 SecondBarPanel / SecondBarView
      Settings/  SettingsView, SettingsWindowController, LaunchAtLogin
