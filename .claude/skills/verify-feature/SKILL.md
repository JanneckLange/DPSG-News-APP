---
name: verify-feature
description: Verify the current feature implementation before review or publishing.
disable-model-invocation: true
---

Verify the current uncommitted work.

Inspect:

- git diff
- modified files
- implementation consistency

For Flutter changes verify:

- formatting
- flutter analyze
- relevant tests
- loading states
- empty states
- error handling
- accessibility
- semantics
- user feedback

For backend changes verify:

- formatting
- lint
- type checking
- relevant tests
- validation
- authentication
- authorization
- error handling
- logging
- API consistency

Also verify:

- Flutter and backend remain compatible.
- No unrelated files were modified.
- No unnecessary dependencies were introduced.
- No obvious performance regressions.
- No breaking API changes without justification.

Return only:
- Blocking issues
- Recommended improvements
- Tests executed
- Tests skipped
- Remaining risks