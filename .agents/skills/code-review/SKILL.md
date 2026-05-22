---
name: code-review
description: Review code changes in this repository for bugs, regressions, security issues, maintainability, missing tests, and violations of project standards. Use when the user asks for a review, code review, PR review, or asks to review recent git changes.
---

# Code Review

## Instructions

1. Run `git status --short` unless the user provided a narrower scope.
2. Run `git diff` for tracked modifications.
3. If `git status --short` shows untracked files, inspect them directly with `git ls-files --others --exclude-standard`, `Get-Content`, or another read-only command.
4. Read the modified or untracked files to understand the intent of the changes.
5. Review against the checklist below.
6. Provide findings first, ordered by severity, with file and line references.
7. Keep summaries brief and secondary to the findings.

## Review Checklist

### Security

- No exposed credentials, API keys, or secrets.
- Validate inputs where needed.
- Sanitize file paths where user-controlled paths are involved.
- Construct external commands safely.

### Code Quality

- Use clear variable and function names.
- Keep functions focused.
- Avoid duplication that creates maintenance risk.
- Keep complex logic documented with short, useful comments.
- Handle errors explicitly.
- Avoid unused imports, variables, and dead code.
- Preserve clean separation of concerns.

### Lua and Project Standards

- Preserve Millennium RPC calling conventions.
- Convert all cache table keys to strings before persistence.
- Account for dkjson sparse array serialization behavior.
- Avoid legacy wrappers or thin compatibility layers.
- Avoid "last updated" dates or authorship in code and docs.
- Do not add emojis in code or docs.

### TypeScript and Frontend Standards

- Preserve Steam library and store runtime constraints.
- Avoid brittle DOM selectors where a nearby stable pattern exists.
- Ensure injected UI does not duplicate on repeated observations.
- Keep services and display code separated.

### Testing

- New backend behavior should have focused Lua tests.
- Edge cases and error conditions should be covered where risk justifies it.
- Lua changes should be verified with `busted.bat tests/`.
- Build-impacting changes should be verified with `npm run build`.

## Output Format

Organize feedback by severity:

```markdown
### Critical
- [file:line] Issue, impact, and suggested fix.

### Warnings
- [file:line] Issue, impact, and suggested fix.

### Suggestions
- [file:line] Optional improvement and benefit.
```

If no issues are found, say that clearly and mention any residual test gaps or risk.
