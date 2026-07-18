# Backend

Apply these rules only when working inside the backend.

## Architecture

* Follow the existing project structure.
* Keep controllers thin.
* Place business logic in services.
* Reuse existing utilities before introducing new abstractions.

## Security

Treat all incoming data as untrusted.

Always consider:

* validation
* authentication
* authorization
* input sanitization
* secure error handling

Never expose:

* stack traces
* secrets
* tokens
* internal implementation details

## Reliability

* Handle expected failure scenarios explicitly.
* Prefer transactions when multiple writes belong together.
* Make retryable operations safe where possible.
* Keep logging useful without exposing sensitive information.

## API design

* Preserve existing API conventions.
* Avoid breaking changes unless explicitly requested.
* Return consistent error responses.
* Validate requests at the API boundary.

## Code quality

* Keep functions focused.
* Avoid duplicated business logic.
* Prefer clear code over clever code.

## Verification

Before finishing:

* Run formatting.
* Run linting.
* Run TypeScript type checking.
* Run relevant tests.
* Highlight security or compatibility risks that remain.
