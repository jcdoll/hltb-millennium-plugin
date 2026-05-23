---
name: add-game-id
description: Add a Steam AppID to HowLongToBeat game ID mapping in backend/game_ids.lua. Use when the user asks to add one game ID mapping, resolve a Steam game name to an AppID and HLTB ID, or add bulk discovered game ID mappings before cleanup.
---

# Add Game ID

Add a Steam AppID to HLTB game ID mapping in `backend/game_ids.lua`.

## Input Formats

Accept three input formats:

### 1. Steam AppID

```text
/add-game-id 1004640
```

### 2. Steam Game Name

```text
/add-game-id "FINAL FANTASY TACTICS - The Ivalice Chronicles"
```

### 3. Full Mapping

```text
/add-game-id 1004640 -> 169173
```

## Instructions

### If given an AppID

1. Fetch the Steam store page to verify the AppID exists:
   `https://store.steampowered.com/app/{APPID}`
2. Search HLTB for the game. See "Searching HLTB".
3. Present a confirmation summary and ask the user to confirm the mapping before editing.

### If given a Steam name only

1. Search for the Steam AppID: `{game_name} site:store.steampowered.com`
2. Extract the AppID from the Steam URL: `store.steampowered.com/app/{APPID}/...`
3. Verify the app by fetching: `https://store.steampowered.com/app/{APPID}`
4. Search HLTB for the game. See "Searching HLTB".
5. Present a confirmation summary and ask the user to confirm the mapping before editing.

### If given a full mapping

1. Parse the arguments to extract the AppID and HLTB ID.
2. Verify the AppID by fetching: `https://store.steampowered.com/app/{APPID}`.
3. Verify the HLTB ID by fetching: `https://howlongtobeat.com/game/{HLTB_ID}`.
4. Present the confirmation summary and ask the user to confirm the mapping before editing.

### Searching HLTB

Prefer direct HLTB verification when accessible. Use the HLTB page to confirm the numeric ID, HLTB name, and Steam profile link when present.

If direct HLTB search or verification fails, use IsThereAnyDeal as a proxy or cross-check:

1. Search: `{game_name} IsThereAnyDeal`
2. Find the IsThereAnyDeal game page in results: `isthereanydeal.com/game/{slug}/info/`
3. Fetch the IsThereAnyDeal page to get the HLTB game ID and name.
4. Construct the HLTB URL: `https://howlongtobeat.com/game/{id}`

### Confirmation Output Format

Always present this exact format before asking for user confirmation:

```markdown
- **AppID:** {appid}
- **Steam name:** "{name from Steam page}"
- **HLTB ID:** {numeric ID}
- **HLTB name:** "{exact name from HLTB}"
- **HLTB page:** {URL}
```

### Adding the Mapping

1. Read `backend/game_ids.lua`.
2. Check whether the AppID already exists.
   - If it exists, stop and report the existing mapping instead of adding a duplicate.
   - If the existing mapping differs from the proposed HLTB ID, report both values and ask the user how to proceed.
3. Find the correct position to maintain numerical order by AppID.
4. Insert the new mapping:

```lua
[{APPID}] = {HLTB_ID}, -- {HLTB game name}
```

5. Report the mapping that was added.
6. Run verification:

```powershell
busted.bat tests/game_ids_spec.lua
npm run build
```

If `busted.bat` is unavailable, try:

```powershell
busted tests/game_ids_spec.lua
```

If neither Lua test command is available, stop and report the missing dependency. Point the user to `docs/development.md` section "Running Lua Tests".

Use `apply_patch` for edits.

## Bulk Additions

When adding many entries at once, such as from `scripts/discover-game-ids.js` output:

1. Append all new entries to the end of the table before the closing `}`.
2. Do not spend time manually sorting or deduplicating each entry.
3. Run the `game-id-review` skill afterward to sort numerically and remove duplicates.

This is faster than inserting each entry in order.

## Verifying Entries via Steam API

After adding entries, verify them against Steam's API to catch mismatches:

```bash
node -e "
const ids = [APPID1, APPID2]; // Add AppIDs here
(async () => {
  for (const id of ids) {
    const r = await fetch('https://store.steampowered.com/api/appdetails?appids=' + id);
    const d = await r.json();
    const name = d[id]?.data?.name || 'N/A';
    console.log(id + ': ' + name);
    await new Promise(r => setTimeout(r, 200));
  }
})();
"
```

## Example Workflow

For AppID `1004640`:

1. Fetch Steam page: `https://store.steampowered.com/app/1004640`
2. Steam name: `FINAL FANTASY TACTICS - The Ivalice Chronicles`
3. Search: `FINAL FANTASY TACTICS IsThereAnyDeal`
4. Fetch IsThereAnyDeal page to get HLTB game ID.
5. Present confirmation:
   - **AppID:** 1004640
   - **Steam name:** "FINAL FANTASY TACTICS - The Ivalice Chronicles"
   - **HLTB ID:** 169173
   - **HLTB name:** "Final Fantasy Tactics: The Ivalice Chronicles"
   - **HLTB page:** https://howlongtobeat.com/game/169173
6. After confirmation, insert:

```lua
[1004640] = 169173, -- Final Fantasy Tactics: The Ivalice Chronicles
```
