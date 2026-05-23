---
name: new-release
description: Create a new release of the HLTB Millennium plugin. Use when the user asks to release the plugin, bump a version, create a GitHub release, or update the PluginDatabase submodule and PR.
allowed-tools: Read, Edit, Bash, AskUserQuestion
---

# New Release

Read `.agents/skills/new-release/SKILL.md` and follow it as the canonical workflow for this task.

Use the current user request as the skill input. If this wrapper conflicts with the canonical skill, the canonical skill wins.

Claude Code compatibility:
- Use `Edit` where the canonical skill says `apply_patch`.
- Treat Codex channel instructions as non-applicable in Claude Code.
- Keep this wrapper small; update the canonical `.agents` skill instead of duplicating workflow steps here.
