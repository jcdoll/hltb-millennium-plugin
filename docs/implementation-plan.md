# Implementation Plan

This document outlines the phased implementation plan for the HLTB for Millennium plugin.

## Phase Overview

| Phase | Focus | Deliverable |
|-------|-------|-------------|
| 1 | Project Setup and MVP | Working Desktop UI plugin |
| 2 | Polish and Features | Settings, error handling, styling |
| 3 | Big Picture Mode | GamepadUI support |
| 4 | Testing and Edge Cases | Comprehensive testing |
| 5 | Distribution | Public release |

## Phase 1: Project Setup and MVP

Goal: Create a minimal working plugin that displays HLTB data in Desktop UI.

### 1.1 Initialize Project Structure

Create the following directory structure:

```
hltb-millennium-plugin/
├── plugin.json
├── package.json
├── tsconfig.json
├── .prettierrc
├── frontend/
│   ├── index.tsx
│   ├── tsconfig.json
│   ├── components/
│   │   └── HltbDisplay.tsx
│   ├── services/
│   │   ├── hltbApi.ts
│   │   └── cache.ts
│   └── utils/
│       └── normalize.ts
└── webkit/
    └── hltb.css
```

### 1.2 Create Plugin Manifest

plugin.json:
```json
{
  "$schema": "https://millennium.web.app/schemas/v2/plugin.schema.json",
  "name": "hltb-for-millennium",
  "common_name": "HLTB for Steam",
  "description": "Displays How Long To Beat completion times on game pages",
  "version": "1.0.0"
}
```

### 1.3 Configure Dependencies

package.json:
```json
{
  "name": "hltb-for-millennium",
  "type": "module",
  "scripts": {
    "dev": "millennium-ttc --build dev",
    "watch": "millennium-ttc --build dev --watch",
    "build": "millennium-ttc --build prod"
  },
  "dependencies": {
    "@steambrew/client": "^5.5.3",
    "@steambrew/api": "^5.5.3",
    "@steambrew/webkit": "^5.5.3"
  },
  "devDependencies": {
    "@steambrew/ttc": "^2.7.3",
    "typescript": "^5.0.0"
  }
}
```

### 1.4 Implement HLTB API Service

See [HLTB API](hltb-api.md) for details on the API structure.

### 1.5 Implement Caching Layer

Cache structure:
```typescript
interface CacheEntry {
  data: HltbGameResult | null;
  timestamp: number;
  notFound: boolean;
}

const CACHE_KEY = 'hltb-millennium-cache';
const CACHE_DURATION = 2 * 60 * 60 * 1000; // 2 hours
```

### 1.6 Create Display Component

Basic component showing completion times:
```typescript
function HltbDisplay({ data }: { data: HltbGameResult }) {
  return (
    <div className="hltb-container">
      <div className="hltb-header">How Long To Beat</div>
      <div className="hltb-stats">
        <div className="hltb-stat">
          <span className="label">Main Story</span>
          <span className="value">{formatTime(data.comp_main)}</span>
        </div>
        {/* Additional stats */}
      </div>
    </div>
  );
}
```

### 1.7 Implement UI Injection

Use MutationObserver to detect game page navigation:
```typescript
function windowCreated(context: any) {
  const observer = new MutationObserver((mutations) => {
    const appMatch = window.location.href.match(/\/library\/app\/(\d+)/);
    if (appMatch) {
      const appId = parseInt(appMatch[1]);
      injectHltbData(appId);
    }
  });
  observer.observe(document.body, { childList: true, subtree: true });
}
```

### 1.8 Target Desktop Window Only

Limit initial implementation to Desktop UI:
```typescript
export default definePlugin(() => {
  Millennium.AddWindowCreateHook(windowCreated);
  return {
    title: 'HLTB for Steam',
    content: <SettingsPanel />,
  };
});
```

## Phase 2: Polish and Features

Goal: Add settings, error handling, and visual polish.

### 2.1 Settings Panel

Create settings UI with toggles for each stat type:
```typescript
function SettingsPanel() {
  return (
    <>
      <Field label="Show Main Story">
        <Toggle value={settings.showMainStory} onChange={...} />
      </Field>
      <Field label="Show Main + Extras">
        <Toggle value={settings.showMainPlusExtras} onChange={...} />
      </Field>
      {/* Additional settings */}
      <Field label="Clear Cache">
        <DialogButton onClick={clearCache}>Clear</DialogButton>
      </Field>
    </>
  );
}
```

### 2.2 Game Matching Improvements

Implement fuzzy matching with Levenshtein distance:
```typescript
function findBestMatch(gameName: string, appId: number, results: HltbGameResult[]) {
  // Priority 1: Steam appId match
  const appIdMatch = results.find(r => r.profile_steam === appId);
  if (appIdMatch) return appIdMatch;

  // Priority 2: Exact name match
  const exactMatch = results.find(r => normalize(r.game_name) === normalize(gameName));
  if (exactMatch) return exactMatch;

  // Priority 3: Fuzzy match
  const fuzzyMatches = results
    .map(r => ({ ...r, distance: levenshtein(normalize(gameName), normalize(r.game_name)) }))
    .filter(r => r.distance < normalize(gameName).length * 0.3)
    .sort((a, b) => a.distance - b.distance);

  return fuzzyMatches[0] ?? null;
}
```

### 2.3 Loading and Error States

Add visual feedback for loading and errors:
```typescript
function HltbContainer({ appId }: { appId: number }) {
  const { data, loading, error } = useHltb(appId);

  if (loading) return <div className="hltb-loading">Loading...</div>;
  if (error) return <div className="hltb-error">Could not load HLTB data</div>;
  if (!data) return null;

  return <HltbDisplay data={data} />;
}
```

### 2.4 Styling

Create CSS to match Steam UI aesthetics:
```css
.hltb-container {
  margin-top: 8px;
  padding: 12px;
  background: rgba(0, 0, 0, 0.2);
  border-radius: 4px;
}

.hltb-header {
  font-size: 12px;
  text-transform: uppercase;
  opacity: 0.6;
  margin-bottom: 8px;
}

.hltb-stats {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 8px;
}
```

## Phase 3: Big Picture Mode Support

Goal: Add support for GamepadUI / Big Picture mode.

### 3.1 Window Type Detection

Detect which UI mode is active:
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

### 3.2 Separate Selector Sets

Maintain different selectors for each mode:
```typescript
const SELECTORS = {
  desktop: {
    infoContainer: '._3cntzF30xAuwn1ARWJjvCb',
    appIcon: '._3NBxSLAZLbbbnul8KfDFjw'
  },
  gamepadui: {
    // Different selectors for Big Picture
  }
};
```

### 3.3 Port HLTB-for-Deck Patterns

Reference the Decky plugin for GamepadUI DOM structure:
- Route pattern: `/library/app/:appid`
- Component search via React props traversal
- Similar injection points

### 3.4 Handle Mode Switching

Clean up and reinitialize when switching modes:
```typescript
let currentObserver: MutationObserver | null = null;

function initDesktopMode(context: any) {
  cleanup();
  currentObserver = new MutationObserver(handleDesktopNavigation);
  currentObserver.observe(document.body, { childList: true, subtree: true });
}

function cleanup() {
  if (currentObserver) {
    currentObserver.disconnect();
    currentObserver = null;
  }
}
```

## Phase 4: Testing and Edge Cases

Goal: Comprehensive testing across scenarios.

### 4.1 Game Name Variations

Test with:
- Special characters and symbols
- Very long names
- Localized names (non-English)
- Abbreviated names
- Remasters and re-releases

### 4.2 Error Scenarios

Test handling of:
- Network failures
- API rate limiting
- Invalid responses
- Games not in HLTB database
- Corrupted cache

### 4.3 Navigation Edge Cases

Test:
- Rapid game switching
- Deep linking to games
- Refresh during game view
- Browser back/forward

### 4.4 Big Picture Specific

Test:
- Plugin loading in GamepadUI
- Controller navigation
- Mode switching
- Hibernation recovery (known issue)

## Phase 5: Distribution

Goal: Prepare and publish the plugin.

### 5.1 Documentation

- Write user-facing README
- Add screenshots
- Document installation steps
- List known issues

### 5.2 Submission

- Test on clean Steam installation
- Verify all features work
- Submit to Millennium Plugin Database
- Respond to review feedback

## File Structure Summary

Final project structure:

```
hltb-millennium-plugin/
├── docs/
│   └── (documentation files)
├── frontend/
│   ├── index.tsx
│   ├── tsconfig.json
│   ├── components/
│   │   ├── HltbDisplay.tsx
│   │   ├── HltbContainer.tsx
│   │   └── SettingsPanel.tsx
│   ├── services/
│   │   ├── hltbApi.ts
│   │   ├── cache.ts
│   │   └── gameMatching.ts
│   ├── hooks/
│   │   └── useHltb.ts
│   └── utils/
│       ├── normalize.ts
│       └── levenshtein.ts
├── backend/
│   └── main.lua (if needed for CORS)
├── webkit/
│   └── hltb.css
├── plugin.json
├── package.json
└── tsconfig.json
```
