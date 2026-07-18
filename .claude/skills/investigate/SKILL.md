---
name: investigate
description: Analyze the codebase, identify affected files, propose implementation approaches and risks without modifying code.
disable-model-invocation: true
---

Your goal is to understand the requested feature or bug without making changes.

Do not edit files.

Do not execute write operations.

Tasks:

1. Identify the relevant modules.
2. Read only the files required to understand the feature.
3. Explain the current implementation.
4. Identify the files that would likely need changes.
5. Explain why each file is relevant.
6. Propose one or more implementation approaches.
7. Compare trade-offs.
8. Identify assumptions.
9. Identify technical risks.
10. List questions that should be answered before implementation.

Keep the report concise.

Do not implement anything.