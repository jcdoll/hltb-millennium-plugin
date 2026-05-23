---
name: new-release
description: Create a new release of the HLTB Millennium plugin. Use when the user asks to release the plugin, bump a version, create a GitHub release, or update the PluginDatabase submodule and PR.
---

# New Release

Create a new release of the HLTB for Steam plugin, including version bump, build verification, GitHub release, and PluginDatabase update.

Before running this skill, run the `game-id-review` skill to ensure game IDs are high quality.

## Usage

```text
/new-release
/new-release 1.2.3
/new-release --dry-run
```

If no version is provided, suggest a patch increment.

## Dry Run

When the user asks for a dry run, gather release state and present the release plan only.

Do not:

- edit files
- run `git fetch`
- commit or push
- trigger workflows
- modify GitHub releases
- touch `../PluginDatabase`

Use current local remote-tracking information and state that a real release would fetch before final validation.

## Workflow

### Phase 1: Gather Information

1. Read `plugin.json` and `package.json` to get the current local version.
2. Verify versions match. Abort if they differ.
3. Get latest GitHub release version:

```powershell
gh release list --limit 1 --json tagName --jq '.[0].tagName'
```

4. Check git status:

```powershell
git status --porcelain
git branch --show-current
git fetch origin
git status -uno
```

In dry-run mode, do not run `git fetch origin`; use existing local remote-tracking information instead.

5. Get commits since last release for release notes:

```powershell
git log v{GITHUB_VERSION}..HEAD --oneline --no-merges
```

6. Generate human-readable release notes. Read actual diffs and changes, not only commit messages. Write clear user-facing descriptions grouped by category, such as `Bug fixes` and `Improvements`.

Exclude:

- Version bump commits such as `Release v...`
- Trivial commits such as typos or formatting
- Claude or Codex skill updates under `.claude` or `.agents`
- CI and workflow updates under `.github`

If no release-worthy changes remain after exclusions, stop and report that there is nothing user-facing to release. Continue only if the user explicitly says to release anyway.

7. Verify `../PluginDatabase` exists and contains the submodule:

```powershell
Test-Path ../PluginDatabase/plugins/hltb-millennium-plugin
```

Abort if:

- Local versions do not match.
- Working tree has uncommitted changes.
- Current branch is not `main`.
- Local branch is behind remote.

### Phase 2: Determine New Version

1. Parse current version as `major.minor.patch`.
2. If the user provided a version argument, validate `X.Y.Z` format and use it.
3. Otherwise, calculate a patch increment, such as `1.0.4` -> `1.0.5`.
4. Ask the user to confirm the version before editing.

### Phase 3: Present Execution Plan

Display this format and ask for confirmation:

```markdown
## Release Plan: v{NEW_VERSION}

### Current State
- Local version: {LOCAL_VERSION}
- GitHub release: {GITHUB_VERSION}
- Git: clean, on main, up-to-date

### Release Notes
- {BULLET_POINT_PER_SIGNIFICANT_CHANGE}

### Steps to Execute
1. Update plugin.json version: {OLD} -> {NEW}
2. Update package.json version: {OLD} -> {NEW}
3. Run `npm install` to update package-lock.json
4. Run `npm run build` to verify build succeeds
5. Run Lua tests to verify backend code
6. Commit: "Release v{NEW_VERSION}"
7. Push to origin/main
8. Trigger GitHub Action "Create Release"
9. Wait for release workflow to complete
10. Update GitHub release with human-readable notes
11. Update submodule in ../PluginDatabase to latest commit
12. Commit in PluginDatabase: "Update HLTB for Steam to v{NEW_VERSION}"
13. Push PluginDatabase to origin
14. Create PR to SteamClientHomebrew/PluginDatabase

Proceed with release?
```

Proceed only after explicit user confirmation.

### Phase 4: Execute

Execute each step, reporting progress. Stop immediately on any failure.

#### Step 1-2: Update Versions

Use `apply_patch` to update version in both files.

#### Step 3: npm install

```powershell
npm install
```

#### Step 4: Build

```powershell
npm run build
```

Abort if build fails.

#### Step 5: Run Lua Tests

```powershell
busted.bat tests/
```

If `busted.bat` is not available, try:

```powershell
busted tests/
```

Abort if any tests fail. If neither Lua test command is available, stop and report the missing dependency. Point the user to `docs/development.md` section "Running Lua Tests".

#### Step 6: Commit

```powershell
git add plugin.json package.json package-lock.json
git commit -m "Release v{VERSION}"
```

#### Step 7: Push

```powershell
git push origin main
```

#### Step 8: Trigger GitHub Action

```powershell
gh workflow run release.yml -f version={VERSION}
```

#### Step 9: Wait for Workflow

```powershell
gh run list --workflow=release.yml --limit 1 --json status,conclusion,databaseId
```

Poll every 10 seconds until status is `completed`. Abort if conclusion is not `success`.

#### Step 9.5: Update GitHub Release Notes

The workflow's generated release notes only produce auto-generated commit links. Replace them with the human-readable release notes generated in Phase 1:

```powershell
$releaseNotesPath = "release-notes-v{VERSION}.md"
Set-Content -LiteralPath $releaseNotesPath -Value @"
{RELEASE_NOTES}
"@
gh release edit v{VERSION} --notes-file $releaseNotesPath
```

The notes should include category headers and end with a full changelog link:

```markdown
**Full Changelog**: https://github.com/{OWNER}/{REPO}/compare/v{PREV_VERSION}...v{VERSION}
```

#### Step 10: Update Submodule

```powershell
Push-Location ../PluginDatabase/plugins/hltb-millennium-plugin
git fetch origin
git checkout origin/main
Pop-Location
```

#### Step 11: Commit PluginDatabase

```powershell
Push-Location ../PluginDatabase
git add plugins/hltb-millennium-plugin
git commit -m "Update HLTB for Steam to v{VERSION}"
Pop-Location
```

#### Step 12: Push PluginDatabase

```powershell
Push-Location ../PluginDatabase
git push origin
Pop-Location
```

#### Step 13: Create PR

```powershell
Push-Location ../PluginDatabase
$prBodyPath = "hltb-plugin-database-pr-v{VERSION}.md"
Set-Content -LiteralPath $prBodyPath -Value @"
Updates the HLTB for Steam plugin submodule to v{VERSION}.

## Changes
{RELEASE_NOTES_AS_BULLET_POINTS}
"@
gh pr create --repo SteamClientHomebrew/PluginDatabase --title "Update HLTB for Steam to v{VERSION}" --body-file $prBodyPath
Pop-Location
```

### Completion

Report success with:

- GitHub release URL
- PluginDatabase PR URL

## Error Messages

Provide clear, actionable error messages:

- **Versions don't match**: `plugin.json has version {X} but package.json has version {Y}. Fix this manually before releasing.`
- **Dirty working tree**: `Uncommitted changes detected. Commit or stash changes before releasing.`
- **Wrong branch**: `Currently on branch {X}. Switch to main before releasing.`
- **Behind remote**: `Local main is behind origin/main. Pull latest changes first.`
- **Build failed**: `Build failed. Fix build errors before releasing.`
- **Tests failed**: `Lua tests failed. Fix test failures before releasing.`
- **Workflow failed**: `GitHub release workflow failed. Check Actions tab for details.`
