---
name: game-id-review
description: Review and clean backend/game_ids.lua by detecting duplicate Steam AppID mappings, removing duplicates, verifying comments, and ensuring numerical AppID sort order. Use after adding game ID mappings or when asked to clean game_ids.lua.
---

# Game ID Review

Clean up `backend/game_ids.lua` by removing duplicates and ensuring numerical sort order.

## Instructions

### Step 1: Run Tests to Check Current State

```powershell
busted.bat tests/game_ids_spec.lua
```

Report whether tests pass or fail.

If `busted.bat` is not available, read `docs/development.md` section "Running Lua Tests" for setup instructions.

### Step 2: Read and Parse the File

1. Read `backend/game_ids.lua`.
2. Parse each mapping line to extract AppID, HLTB ID, and comment.
3. Identify issues:
   - Duplicates: same AppID appearing more than once. Keep the first occurrence.
   - Missing comments: entries without an HLTB name comment.
   - Sort order: AppIDs not in ascending numerical order.

### Step 3: Remove Duplicates

Use targeted `apply_patch` edits to remove duplicate lines while keeping the first occurrence.

Do not rewrite unrelated content when only a small number of duplicate lines need removal.

### Step 4: Verify Numerical Sort Order

Check that AppIDs are in ascending numerical order.

If sorting is needed, prefer a deterministic script or command that preserves the table wrapper and mapping lines. Inspect the diff afterward to confirm only ordering changed.

PowerShell approach:

```powershell
$path = "backend/game_ids.lua"
$lines = Get-Content -LiteralPath $path
$header = $lines | Select-Object -First 6
$entries = $lines | Where-Object { $_ -match '^\s*\[\d+\]\s*=' } | Sort-Object { [int]([regex]::Match($_, '\[(\d+)\]').Groups[1].Value) }
$output = @($header) + @($entries) + @("}")
Set-Content -LiteralPath $path -Value $output
```

### Step 5: Verify

Run tests again:

```powershell
busted.bat tests/game_ids_spec.lua
```

For backend-facing changes, run the required build before asking the user to test:

```powershell
npm run build
```

## Output Format

```text
Running tests...
[PASS/FAIL]

Found N issue(s):
- Removed duplicate: AppID {id}
- Missing comment: AppID {id}

Sorted N entries numerically.

Verifying...
[PASS]

Done.
```

If no issues are found and the file is already sorted, report `No changes needed.`
