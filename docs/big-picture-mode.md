# Big Picture Mode Support

This document describes how Steam's Big Picture mode (GamepadUI) works and how to support it in Millennium plugins.

## Overview

Millennium supports Big Picture mode (GamepadUI), but it requires different injection patterns than the Desktop UI. This is because Big Picture uses a completely different DOM structure despite sharing the same underlying React/CEF technology.

## Steam UI Modes

Steam has two distinct UI modes, each running as separate CEF (Chromium Embedded Framework) windows:

| Mode | Window Identifier | Launch Method | Primary Use |
|------|-------------------|---------------|-------------|
| Desktop UI | `SP Desktop_uid0` | Default | Mouse and keyboard |
| GamepadUI | `SP GamepadUI_uid*` | `-gamepadui` flag | Controller, Big Picture, Steam Deck |

Note: GamepadUI is the same interface used on Steam Deck. Any code that works in Big Picture mode on desktop will also work on Steam Deck (via Decky Loader).

## Technical Differences

Both modes use the same underlying technology stack:
- Chromium Embedded Framework (CEF) for rendering
- React for UI components
- Similar routing patterns

However, they have completely different:
- DOM structures and CSS class names
- Component hierarchies
- Visual layouts

A selector that works in Desktop UI will not work in GamepadUI and vice versa.

## Window Detection

Millennium provides hooks to detect when windows are created. Use window name matching to differentiate between modes.

From Extendium implementation:
```typescript
const MAIN_WINDOW_NAME = 'SP Desktop_uid0';
const wnd = g_PopupManager.GetExistingPopup('SP Desktop_uid0');

// Register for all popup/window creation events
g_PopupManager.AddPopupCreatedCallback(OnPopupCreation);
```

The `AddWindowCreateHook` receives context for all Steam windows, including Big Picture.

Example dual-mode detection:
```typescript
function onWindowCreated(context: any) {
  const windowName = context?.m_strName || '';

  if (windowName === 'SP Desktop_uid0') {
    initDesktopMode(context);
  } else if (windowName.includes('GamepadUI')) {
    initGamepadUIMode(context);
  }
}
```

## Known Issues

The following issues have been reported with Big Picture mode in Millennium:

### Black Screen on Hibernation Wake (Issue #489)

Status: Open

When Steam Big Picture's suspend function puts the PC into hibernation, waking the PC causes a black screen. Audio works and controller input registers, but the display is blank.

Workaround: Use Windows sleep mode instead of Big Picture's suspend function.

### Theme Persistence (Issue #96)

Status: Resolved

Skins were not applying correctly after exiting Big Picture mode. This has been fixed in recent Millennium versions.

### Families Beta Crashes (Issue #84)

Status: Resolved

Big Picture mode crashed with Millennium when the Steam Families Beta was active. This has been fixed.

## Implementation Strategy

### Phase 1: Desktop UI Only

For the initial release, focus on Desktop UI:
- Target only `SP Desktop_uid0` window
- Use Desktop UI selectors
- Faster development and testing cycle

### Phase 2: Add Big Picture Support

After Desktop UI is stable:
1. Add window type detection in initialization
2. Create separate selector sets for GamepadUI
3. Port injection logic from hltb-for-deck
4. Test both modes independently
5. Handle mode switching gracefully

## Reusing HLTB-for-Deck Code

Since GamepadUI is the same interface as Steam Deck, the hltb-for-deck plugin provides a direct reference:

Route pattern:
```
/library/app/:appid
```

DOM traversal approach:
- Deep React props navigation to find injection point
- Search for components with specific prop patterns
- Same game details layout as Steam Deck

The main difference is the hooking mechanism:
- Decky uses `serverApi.routerHook.addPatch()`
- Millennium uses `g_PopupManager` + DOM observation

## Selector Strategy

Maintain separate selector configurations for each mode:

```typescript
const SELECTORS = {
  desktop: {
    infoContainer: '._3cntzF30xAuwn1ARWJjvCb._1uS70KI6ZbUE94jUB27ioB',
    appIcon: '._3NBxSLAZLbbbnul8KfDFjw._2dzwXkCVAuZGFC-qKgo8XB'
  },
  gamepadui: {
    // Different selectors for Big Picture mode
    // Reference hltb-for-deck for current selectors
  }
};
```

## Testing Big Picture Mode

Launch Steam in Big Picture mode with development features:

```powershell
steam.exe -gamepadui -dev
```

```bash
steam -gamepadui -dev
```

Testing checklist:
1. Plugin loads without errors
2. HLTB data appears on game pages
3. Controller navigation works
4. Switching between Desktop and Big Picture modes works
5. Test after PC hibernation (known issue scenario)

## Comparison Table

| Aspect | Desktop UI | Big Picture/GamepadUI |
|--------|------------|----------------------|
| Support Level | Full | Partial (some known issues) |
| Window Detection | `SP Desktop_uid0` | `SP GamepadUI_*` pattern |
| DOM Selectors | Standard class names | Different class names |
| Route Patterns | URL-based | URL-based (same pattern) |
| Injection Point | Info panel | Different layout |
| Reference Code | AugmentedSteam | hltb-for-deck |

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Hibernation black screen | Document as known issue, graceful fallback |
| Different DOM structure | Maintain separate selector sets |
| Mode switching breaks state | Re-initialize on window creation |
| Steam Deck vs desktop differences | Test in both environments |
