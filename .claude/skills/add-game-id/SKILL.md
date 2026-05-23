---
name: add-game-id
description: Add a Steam AppID to HowLongToBeat game ID mapping in backend/game_ids.lua. Use when the user asks to add one game ID mapping, resolve a Steam game name to an AppID and HLTB ID, or add bulk discovered game ID mappings before cleanup.
allowed-tools: Read, Edit, WebFetch, WebSearch
---

# Add Game ID

Read `.agents/skills/add-game-id/SKILL.md` and follow it as the canonical workflow for this task.

Use the current user request as the skill input. If this wrapper conflicts with the canonical skill, the canonical skill wins.

Claude Code compatibility:
- Use `Edit` where the canonical skill says `apply_patch`.
- Treat Codex channel instructions as non-applicable in Claude Code.
- Keep this wrapper small; update the canonical `.agents` skill instead of duplicating workflow steps here.
