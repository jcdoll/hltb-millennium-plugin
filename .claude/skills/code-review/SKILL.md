---
name: code-review
description: Review code changes in this repository for bugs, regressions, security issues, maintainability, missing tests, and violations of project standards. Use when the user asks for a review, code review, PR review, or asks to review recent git changes.
allowed-tools: Read, Grep, Glob, Bash
---

# Code Review

Read `.agents/skills/code-review/SKILL.md` and follow it as the canonical workflow for this task.

Use the current user request as the skill input. If this wrapper conflicts with the canonical skill, the canonical skill wins.

Claude Code compatibility:
- Use Claude Code's normal read-only inspection tools where the canonical skill names Codex shell commands.
- Treat Codex channel instructions as non-applicable in Claude Code.
- Keep this wrapper small; update the canonical `.agents` skill instead of duplicating workflow steps here.
