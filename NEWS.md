# typesafer 0.1.0

Initial development of an unofficial R client for the TypeSafe AI API.

- Add `create_typesafe_client()` with API key, base URL, model, timeout and
  retry configuration through explicit arguments and supported environment
  variables.
- Add `list_models()` for model discovery and `evaluate_questions()` for
  evaluating named questions against a single state.
- Add `create_noul_question()`, `create_choice_question()` and
  `create_score_question()`, including support for mixed question types in one
  evaluation request.
- Validate inputs and serialize structured content with explicit JSON mappings.
  Preserve API response fields, nested structures and numeric precision.
- Add bounded retries for HTTP 429 and 529, with support for server retry
  headers and a total request time budget.
- Add error classes for invalid inputs, HTTP failures, connection failures,
  timeouts and malformed responses, with credential redaction in diagnostics.
- Document the API interface, authentication, JSON conventions and GitHub
  installation.
- Add offline tests and opt-in live API tests. Configure GitHub Actions to run
  package checks on Linux, Windows and macOS with live API tests disabled.
- Declare GPL-3 licensing and include the full GNU GPL v3 text in `LICENSE.md`.
