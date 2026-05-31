# SystemBar

A tidy, transparent menu-bar manager for macOS — collapse the clutter, pin the
icons you always want, and reveal everything on click. Built because Bartender
(closed-source, changed ownership) and Hidden Bar don't solve the notch problem
or per-icon pinning well enough.

> Design goal: no Screen Recording by default. The core collapse/reveal uses no
> special permissions at all. The Second Bar lists icons via the public window
> list + Accessibility; pixel-perfect Screen Recording is kept strictly opt-in.

## Status

Working today:

- [x] Menu-bar control item (chevron) + expanding divider
- [x] Collapse / reveal menu-bar icons (expanding-separator trick — 0 permissions)
- [x] Right-click menu (Show/Hide, Open Second Bar, Settings, Quit), persisted state
- [x] Floating Second Bar — lists every status item as app-icon + name, notch-immune
- [x] Click a Second Bar item -> reveals + clicks the real icon (Accessibility, no Screen Recording)
- [x] Settings window: auto-collapse, launch at login, Accessibility status
- [x] Launch at login (SMAppService)
- [ ] Pin individual icons via UI (today: Cmd-drag relative to divider)
- [ ] Global hotkey to summon the Second Bar
- [ ] (Opt-in) Screen Recording fidelity for pixel-perfect icons

## Build & run

    ./scripts/bundle.sh            # -> build/SystemBar.app
    open build/SystemBar.app

Rebuild & relaunch:

    ./scripts/bundle.sh && killall SystemBar; open build/SystemBar.app

## Interaction

- Left-click the chevron  -> opens the Second Bar (shows everything, notch-safe).
- Right-click the chevron -> menu (toggle hide, Second Bar, Settings, Quit).
- Cmd-drag icons left/right of the diagonal divider to choose what hides.

## How collapsing works

macOS has no public API to hide another app's menu-bar icon. The only working
technique (used by Bartender / Ice / Hidden Bar) is the expanding separator:

1. SystemBar adds its own divider status item to the menu bar.
2. You Cmd-drag the icons you want to hide to the left of that divider.
3. Collapsing expands the divider so it pushes everything on its left off the
   screen edge. Revealing shrinks it back.

Icons kept to the right of the divider stay always-visible (your pins).

## Permissions

| Feature | Permission | Why |
|---|---|---|
| Collapse / reveal | none | expanding-separator trick |
| List items in Second Bar | none | reads the public window list (CGWindowListCopyWindowInfo) |
| Click a hidden item | Accessibility | synthesizes a click into the owning app — never Screen Recording |
