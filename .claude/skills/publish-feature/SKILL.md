---
name: publish-feature
description: Verify, push and create a GitHub pull request for the current feature branch.
disable-model-invocation: true
---

The user invoking this skill explicitly approves pushing the current feature branch and creating a GitHub Pull Request.

Never merge a Pull Request.

Workflow:

1. Verify the current branch.

Abort if:

- current branch is main or master
- merge conflicts exist
- detached HEAD
- GitHub CLI is unavailable

2. Review:

- git status
- git diff
- commit history

3. Execute the project's quality gates.

Abort if critical failures exist.

4. If relevant uncommitted feature changes remain:

- stage only feature files
- create one Conventional Commit

5. Push the branch.

6. Create a GitHub Pull Request targeting main.

Generate a PR description containing:

## Summary

## Flutter changes

## Backend changes

## Testing

## Risks

Finally return:

- Pull Request URL
- branch name
- commits included
- remaining known risks

Never:

- merge
- force push
- delete branches
