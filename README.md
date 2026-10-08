# typesafer

`typesafer` is an R package in development for accessing the TypeSafe AI API.
The first release will provide a thin, synchronous client that maps the HTTP
API to R functions and preserves its request and response structures.

## Status and scope

The repository currently contains package metadata and design documentation.
There is no usable API client yet. Functions, tests, installation instructions
and runnable examples will be added during implementation.

The initial scope covers:

- model discovery through `GET /v1/models`;
- evaluation through `POST /v1/systemone`;
- Noul, Choice and Score questions, including mixed questions in one request;
- authentication, validation, JSON serialization, timeouts, bounded retries
  and understandable errors;
- nested list responses preserving answers, model information and token usage.

Data-frame workflows, vectorised evaluation, asynchronous execution, caching,
classification helpers and statistical summaries are deferred to a later
higher-level interface.

See the [API contract](docs/api-contract.md) for input and output structures,
JSON mappings and discrepancies verified against the live API.

## Planned R interface

These functions are agreed design targets and are not implemented yet.

| Function | Responsibility |
| --- | --- |
| `create_typesafe_client()` | Create a lightweight S3 client holding configuration |
| `list_models(client)` | Retrieve available models and aliases |
| `evaluate_questions(client, state, questions, model)` | Evaluate named questions against one state |
| `create_noul_question(instructions = NULL, criteria = NULL)` | Construct a Noul question |
| `create_choice_question(criteria, instructions = NULL)` | Construct a Choice question |
| `create_score_question(criteria, instructions = NULL)` | Construct a Score question |

Question constructors will return ordinary lists. Evaluation will also accept
manually assembled question lists with the same structure. Endpoint functions
will return nested lists with API field names unchanged.

## Planned configuration and authentication

Configuration precedence will be explicit arguments, then supported environment
variables, then package defaults. Explicitly supplied invalid values will
produce errors rather than falling back silently.

| Setting | Environment variable | Default |
| --- | --- | --- |
| API key | `TYPESAFE_API_KEY` | None; required |
| API base URL | `TYPESAFE_BASE_URL` | `https://api.typesafe.ai` |
| Default model | `TYPESAFE_DEFAULT_MODEL` | `jev-latest` |

R reads these variables from `.Renviron` at session startup when configured
there. The client will read the session environment; it will not read or modify
`.Renviron` itself. Keys must never be committed, printed in client summaries
or included in diagnostic messages.

Client construction will make no network request. Endpoint calls will send
bearer-authenticated HTTPS requests; evaluation sends supplied content and
questions to TypeSafe. Timeout and retry limits will be explicit client
settings, with defaults documented when transport is implemented.

Users may supply any model name, including a pinned version, without a model
discovery call. The actual model reported by the API will remain in the result.

## Planned architecture

Public endpoint functions will share internal helpers for validation,
serialization, HTTP requests and errors. The client will be a small S3 list.
The following source files are planned; they do not exist yet.

| File | Responsibility |
| --- | --- |
| `R/client.R` | Client construction, configuration and safe printing |
| `R/questions.R` | Question constructors |
| `R/system_one.R` | Evaluation endpoint |
| `R/models.R` | Model discovery endpoint |
| `R/request.R` | Authentication, HTTP execution, timeouts and retries |
| `R/validation.R` | Input checks and JSON shape handling |
| `R/errors.R` | Package conditions and diagnostic extraction |

`httr2` is the planned HTTP dependency. Dependencies will be declared in
DESCRIPTION when introduced; additional dependencies require a concrete need.
Minimum R and dependency versions will be set alongside the implementation
that requires them.

The client will preserve server-provided values and unknown response fields.
It will not recompute confidence, round scores, renumber rubric levels or
automatically convert responses into data frames.

## Development plan

1. Record the contract and package scope: complete metadata and document the
   interface, configuration, JSON mappings and observed API constraints.
2. Implement the client and transport: authentication, timeouts, errors and
   model discovery, with offline request tests.
3. Implement evaluation and constructors: all three primitives, mixed
   questions, structured inputs and faithful response decoding.
4. Complete regression tests: validation boundaries, JSON shapes, responses,
   errors, retry exhaustion and credential redaction.
5. Document and validate: generate function help and exports with roxygen2,
   add a runnable quick start and CI, and run package checks.

The first release requires both endpoints and all three primitives to work,
offline tests to pass, documentation to be generated and `R CMD check` to pass.
Authenticated integration results will be reported separately.

## Testing and contributing

Follow [AGENTS.md](AGENTS.md) and the existing `.lintr` configuration. There are
currently no tests or CI configuration. Planned tests use `testthat` edition 3
and saved fixtures or mocks, without Internet access or personal credentials.
Live tests will require both `RUN_NETWORK_TESTS=true` and an API key; ordinary
test runs will skip them. Retry tests will mock delays and responses.

Once implementation and development dependencies exist, run from the repository
root:

```r
devtools::document()
devtools::test()
devtools::check()
```

Edit roxygen comments in source files and regenerate documentation and exports.
Keep changes focused and preserve existing work.

## References and license

- [TypeSafe general documentation](https://docs.typesafe.ai/)
- [HTTP API reference](https://docs.typesafe.ai/api)
- [Swagger API reference](https://api.typesafe.ai/docs)
- [OpenAPI schema](https://api.typesafe.ai/openapi.json)

Licensed under GPL-3, as declared in [DESCRIPTION](DESCRIPTION).
