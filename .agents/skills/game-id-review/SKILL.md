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

If `busted.bat` is not available, try:

```powershell
busted tests/game_ids_spec.lua
```

If both commands are unavailable, stop and report the missing Lua test dependency. Point the user to `docs/development.md` section "Running Lua Tests" for setup instructions.

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

If sorting is needed, prefer a deterministic script or command that preserves:

- all prefix lines before the first mapping
- all mapping lines, sorted by numeric AppID
- all suffix lines after the last mapping

If unexpected non-mapping content appears between mapping lines, stop and ask before rewriting the file.

PowerShell approach:

```powershell
$path = "backend/game_ids.lua"
$lines = Get-Content -LiteralPath $path
$mappingIndexes = for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^\s*\[\d+\]\s*=') { $i }
}
if (-not $mappingIndexes) { throw "No mapping lines found" }
$first = $mappingIndexes[0]
$last = $mappingIndexes[-1]
$prefix = if ($first -gt 0) { $lines[0..($first - 1)] } else { @() }
$mappingBlock = $lines[$first..$last]
$suffix = if ($last -lt ($lines.Count - 1)) { $lines[($last + 1)..($lines.Count - 1)] } else { @() }
$nonMappings = $mappingBlock | Where-Object { $_ -notmatch '^\s*\[\d+\]\s*=' }
if ($nonMappings) { throw "Unexpected non-mapping content inside mapping block" }
$entries = $mappingBlock | Sort-Object { [int]([regex]::Match($_, '\[(\d+)\]').Groups[1].Value) }
$output = @($prefix) + @($entries) + @($suffix)
Set-Content -LiteralPath $path -Value $output
```

After editing, inspect the diff:

```powershell
git diff -- backend/game_ids.lua
```

Confirm only the intended duplicate removal or sorting changes occurred before verification.

### Step 5: Verify

Run tests again:

```powershell
busted.bat tests/game_ids_spec.lua
```

If needed, use the same `busted` fallback from Step 1.

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
