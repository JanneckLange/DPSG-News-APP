---
name: backend-review
description: Review backend code for security, reliability and API quality.
disable-model-invocation: true
---

Review only backend changes.

Do not modify code.

Evaluate:

## Architecture

- service separation
- controller responsibilities
- code duplication

## Security

- validation
- authentication
- authorization
- secrets
- injection risks

## API

- request validation
- response consistency
- status codes
- breaking changes

## Reliability

- transactions
- retries
- error handling
- logging

## Performance

- expensive queries
- unnecessary work
- N+1 problems

Classify findings:

- High
- Medium
- Low

Finish with the three highest priority improvements.