# Overview

[Millennium](https://steambrew.app/) plugin that displays [How Long To Beat](https://howlongtobeat.com/) completion time data on game pages in the Steam library and store.

## Repository Layout

- `backend/` - Lua backend (runs in Millennium's Lua runtime)
  - `main.lua` - RPC entry points (GetHltbData, settings, cache management)
  - `hltb_api.lua` - HLTB API client (auth, search, game data fetching)
  - `hltb_endpoint_discovery.lua` - scrapes HLTB's JS bundles for dynamic API endpoints
  - `hltb_match.lua` - name matching and scoring logic
  - `hltb_utils.lua` - name sanitization, similarity calculation, time formatting
  - `cache.lua` - result cache and ID cache with disk persistence
  - `settings.lua` - user settings management
  - `steam.lua` - Steam Web API integration
  - `steamhunters.lua` - SteamHunters fallback for game names
  - `game_ids.lua` - manual Steam AppID to HLTB game ID mappings
- `frontend/` - library page UI (TSX, runs in Steam's SP Desktop/Big Picture)
  - `injection/` - DOM observer and game page detection
  - `display/` - HLTB data display components and styles
  - `services/` - backend RPC calls
  - `debug/` - debug tools exposed via `hltbDebug` in console
- `webkit/` - store page UI (TS, runs in store.steampowered.com)
- `tests/` - Lua unit tests (busted)
- `scripts/` - CLI utilities for game ID discovery
- `docs/` - architecture and development documentation
- `.github/workflows/` - CI, release, and API monitoring workflows

## Tech Stack

- TypeScript + TSX (frontend and webkit)
- Lua (backend, runs in Millennium runtime)
- dkjson (loaded as `require("json")` via package.loaded)
- busted for Lua testing
- @steambrew/ttc for building

## Commands

```
npm install
npm run dev
npm run build
busted.bat tests/
busted.bat tests/ --verbose
```

## Safety

- Never run `git reset --hard` (destructive)

## Workflow

- Plan first, share plan, get explicit approval before implementing
- Never assume a good plan means you should implement it
- If unsure or stuck, ask the user
- If something fails, do not silently move on - ask for clarification

## Rebuilding

- Always run `npm run build` after backend (Lua) changes before asking the user to test
- Frontend/webkit changes can be hot-reloaded with F5 in Steam (requires `-dev` flag)
- Backend changes require a full Steam restart after building

## Testing

- Run `busted.bat tests/` after Lua changes; all tests must pass before task is complete
- Run `npm run build` to verify the build succeeds

## Code Quality

- Maintain clean, readable code without legacy baggage
- When refactoring, delete old interfaces - no legacy wrappers or thin compatibility layers
- All cache table keys must be strings (tostring) to avoid dkjson sparse array serialization errors
- Millennium maps TS callable object keys to Lua positional args alphabetically

## Documentation

- No emojis in code or docs
- No excessive bold in markdown; use styling selectively
- No "last updated" dates or authorship
