---
name: game-id-review
description: Review and clean backend/game_ids.lua by detecting duplicate Steam AppID mappings, removing duplicates, verifying comments, and ensuring numerical AppID sort order. Use after adding game ID mappings or when asked to clean game_ids.lua.
allowed-tools: Read, Edit, Bash
---

# Game ID Review

Read `.agents/skills/game-id-review/SKILL.md` and follow it as the canonical workflow for this task.

Use the current user request as the skill input. If this wrapper conflicts with the canonical skill, the canonical skill wins.

Claude Code compatibility:
- Use `Edit` where the canonical skill says `apply_patch`.
- Treat Codex channel instructions as non-applicable in Claude Code.
- Keep this wrapper small; update the canonical `.agents` skill instead of duplicating workflow steps here.
