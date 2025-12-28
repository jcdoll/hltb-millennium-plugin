# Overview

This project is a [Millennium](https://steambrew.app/) plugin that displays [How Long To Beat](https://howlongtobeat.com/) completion time data on game pages in the Steam library.

## Development flow

### Always plan first
- Typical workflow: user makes a request, you formulate a plan, you share the plan for approval. If approved you implement the plan.
- NEVER assume that presenting a good plan means you should implement it. Request approval.

### Follow user requirements
- If you think that functionality is worthwhile, propose it to the user and ask for their approval, do not simply add it.
- Do not add functionality the user did not explicitly approve or request.
- When in doubt, ask for clarification rather than making assumptions.

### You apply edits to the code
- Do not suggest changes and ask the user to apply them. Apply them yourself after receiving approval.

## Code style

### Documentation Standards
- Do not use excessive bold in markdown documents. Only use font styling selectively.
- Do not use emojis in either code or docs.
- Do not include "last updated" dates for documentation or code.

### Code quality

- IMPORTANT: Maintain clean, readable code without legacy baggage. For example, when refactoring delete the old interface instead of adding thin wrappers.
