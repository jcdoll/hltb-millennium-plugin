# Architecture

This document describes the technical architecture of the HLTB for Millennium plugin, including comparisons with related projects and key design decisions.

## Platform Comparison

The following table compares the Decky Loader platform (Steam Deck) with the Millennium platform (Desktop).

| Aspect | Decky (Steam Deck) | Millennium (Desktop) |
|--------|-------------------|---------------------|
| Frontend | TypeScript/React | TypeScript/React |
| Backend | Python | Lua |
| UI Hooks | `decky-frontend-lib` | `@steambrew/client` APIs |
| Build Tool | Rollup | Bun + `@steambrew/ttc` |
| DOM Access | `serverApi.routerHook` | `Millennium.findElement()` |
| HTTP Requests | `serverApi.fetchNoCors()` | Lua `http` module or `fetch()` |

Both platforms use React for the frontend, which allows significant code reuse for UI components and business logic.

## Code Reuse Analysis

### Reusable Components (60-70%)

The following components from hltb-for-deck can be adapted with minimal changes:

1. HLTB API Logic
   - HTTP POST request construction
   - Response parsing
   - Error handling

2. Game Name Normalization
   - Unicode normalization (NFD)
   - Diacritic removal
   - Special character filtering
   - Case normalization

3. Game Matching Algorithm
   - Steam App ID matching via `profile_steam` field
   - Exact normalized name matching
   - Fuzzy matching with Levenshtein distance
   - Result ranking by completion count

4. Caching Logic
   - Cache key structure
   - TTL-based expiration
   - Storage format

5. Display Component Structure
   - Stats layout (Main, Plus, 100%, All Styles)
   - Time formatting
   - Link to HLTB website

### Components Requiring Rewrite (30-40%)

1. UI Injection
   - Decky uses route patching via `serverApi.routerHook.addPatch()`
   - Millennium uses `Millennium.findElement()` with CSS selectors
   - Different DOM structures between Desktop UI and GamepadUI

2. Backend Communication
   - Decky uses Python with `serverApi.fetchNoCors()`
   - Millennium uses Lua with `http` module
   - Alternative: frontend-only with `fetch()` if CORS permits

3. Storage API
   - Decky uses `localforage` (IndexedDB wrapper)
   - Millennium uses browser `localStorage`

4. Settings UI
   - Decky uses Quick Access Menu components
   - Millennium uses `definePlugin()` pattern with `Field`, `Toggle`, `DialogButton`

## Plugin Architecture

### Directory Structure

```
hltb-millennium-plugin/
├── plugin.json              # Plugin manifest
├── package.json             # Dependencies and build scripts
├── tsconfig.json            # TypeScript configuration
├── frontend/
│   ├── index.tsx            # Plugin entry point
│   ├── components/
│   │   ├── HltbDisplay.tsx  # Stats display component
│   │   ├── HltbContainer.tsx # Loading/error wrapper
│   │   └── SettingsPanel.tsx # Plugin settings
│   ├── services/
│   │   ├── hltbApi.ts       # HLTB API client
│   │   ├── cache.ts         # Caching layer
│   │   └── gameMatching.ts  # Name matching logic
│   ├── hooks/
│   │   └── useHltb.ts       # React hook for HLTB data
│   └── utils/
│       ├── normalize.ts     # String normalization
│       └── levenshtein.ts   # Fuzzy matching
├── backend/
│   └── main.lua             # Lua backend (optional)
└── webkit/
    └── hltb.css             # Custom styles
```

### Data Flow

```
User navigates to game page
         │
         ▼
Window hook detects navigation
         │
         ▼
Extract App ID from URL/DOM
         │
         ▼
Check local cache
         │
    ┌────┴────┐
    │ cached  │ not cached
    ▼         ▼
Return data   Fetch from HLTB API
              │
              ▼
         Match game in results
              │
              ▼
         Store in cache
              │
              ▼
         Return data
              │
              ▼
    Inject display component
```

## Key Technical Decisions

### Decision 1: Frontend-Only vs Backend

Recommendation: Start with frontend-only using `fetch()`. Add Lua backend only if CORS blocking occurs.

Rationale:
- Simpler architecture with fewer moving parts
- AugmentedSteam used frontend-only approach via their proxy API
- HLTB may not enforce strict CORS (requires verification)
- Lua backend adds complexity and requires Steam restart for changes

### Decision 2: Element Selection Strategy

Recommendation: Use MutationObserver with CSS selector matching via `Millennium.findElement()`.

Rationale:
- Steam UI uses obfuscated class names that change between updates
- Need to monitor for SPA navigation events
- AugmentedSteam successfully uses this approach
- Fallback selectors can handle minor Steam updates

### Decision 3: Cache Storage

Recommendation: Use localStorage with JSON serialization.

Rationale:
- Simpler than IndexedDB
- Sufficient capacity for HLTB data (small payloads)
- Synchronous access simplifies code
- Matches AugmentedSteam approach

### Decision 4: Dual UI Mode Support

Recommendation: Implement Desktop UI first, add Big Picture support in subsequent phase.

Rationale:
- Desktop UI is primary use case
- Big Picture requires different selectors and injection points
- Can reuse hltb-for-deck patterns for GamepadUI
- Allows faster initial release

## Risk Mitigation

| Risk | Mitigation Strategy |
|------|---------------------|
| HLTB API changes | Abstract API layer, version detection |
| Steam UI class changes | Multiple fallback selectors, semantic matching |
| CORS blocking | Lua backend as fallback option |
| HLTB rate limiting | Aggressive caching (2+ hour TTL), request debouncing |
| Game matching failures | Multiple matching strategies, manual override |
| Big Picture issues | Document known issues, graceful degradation |
| Mode switching | Re-initialize on window creation, clean observer cleanup |
