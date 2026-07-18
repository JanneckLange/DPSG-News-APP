# Project

This repository is a monorepo containing:

* Flutter application: `app/`
* Node.js TypeScript backend: `server/`

Preserve the existing architecture, naming conventions and project structure unless the task explicitly requires otherwise.

## Repository boundaries

Do not read or modify generated or dependency directories:

* `**/node_modules/**`
* `**/.dart_tool/**`
* `**/build/**`
* `**/coverage/**`
* `*.g.dart`
* `*.freezed.dart`

Never read or modify `.env` files.

Never expose secrets in responses or logs.

## Planning

Before implementing:

* Read only the files that are likely relevant to the task.
* Never scan the repository broadly. Expand the search incrementally only when required.
* Identify the files you expect to modify and explain why.
* Follow existing architecture and patterns.
* Keep the scope focused on the requested task.
* Challenge my proposed solution if you find a simpler, safer, more maintainable or more user-friendly alternative. Explain the trade-offs briefly.
* State assumptions, risks and open questions whenever they affect the implementation.
* Ask clarifying questions whenever requirements are ambiguous or multiple reasonable implementations exist. Never continue based on unconfirmed assumptions.
* Prefer the smallest change that satisfies the requirements.
* Reuse existing components before introducing new abstractions or dependencies.
* If additional files become necessary, explain why before expanding the scope.
* If you discover a significantly better approach, pause and explain it before changing direction.

## Workflow

* Work on one feature or bug per session.
* Create a short implementation plan before changes affecting multiple files, APIs, persistence, authentication or architecture.
* Prefer small vertical slices over large rewrites.
* Fix root causes instead of introducing workarounds.
* Avoid unrelated refactoring or cleanup.
* Do not add dependencies without explicit approval.
* Stop before destructive database changes or breaking API contracts.
* Preserve existing UI and architecture unless explicitly requested otherwise.
* Use proper German spelling (Umlaute and ß) in German Markdown prose. Keep code, paths, identifiers, URLs, environment variables and technical literals ASCII.

## Quality

Before considering a task complete:

* Verify error handling.
* Verify loading, empty and error states where applicable.
* Consider accessibility.
* Consider edge cases.
* Consider user feedback.

## Git

Never work directly on `main` or `master`.

Development must happen inside a feature branch or Claude worktree.

If the current branch is `main` or `master`, stop and instruct me to restart Claude using a worktree.

Create local checkpoint commits after coherent vertical slices.

Never automatically:

* push
* create pull requests
* merge
* rebase
* delete branches

Pushing and PR creation are only allowed when I explicitly invoke `/publish-feature`.

## Context compaction

When compacting, preserve:

* current task
* acceptance criteria
* implementation plan
* changed files
* architectural decisions
* test results
* remaining work
* known risks
