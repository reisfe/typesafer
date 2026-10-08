# typesafer

`typesafer` is an R package in development for accessing the TypeSafe AI API.
The first release will provide a thin, synchronous client that maps the HTTP
API to R functions and preserves its request and response structures.

## Status and scope

Client configuration, shared transport and model discovery are implemented.
Evaluation and question constructors remain planned for step 3. Offline tests
cover the implemented functions; CI is not configured yet.

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

## R interface

`create_typesafe_client()` and `list_models()` are implemented. Evaluation and
question constructors below are agreed design targets for step 3.

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

## Configuration and authentication

Configuration precedence is explicit arguments, then supported environment
variables, then package defaults. Explicitly supplied invalid values produce
errors rather than falling back silently.

| Setting | Environment variable | Default |
| --- | --- | --- |
| API key | `TYPESAFE_API_KEY` | None; required |
| API base URL | `TYPESAFE_BASE_URL` | `https://api.typesafe.ai` |
| Default model | `TYPESAFE_DEFAULT_MODEL` | `jev-latest` |

R reads these variables from `.Renviron` at session startup when configured
there. The client reads the session environment; it does not read or modify
`.Renviron` itself. Keys must never be committed, printed in client summaries
or included in diagnostic messages.

Client construction makes no network request. Endpoint calls send
bearer-authenticated HTTPS requests; evaluation sends supplied content and
questions to TypeSafe once evaluation is implemented. Client settings default
to a 10-second timeout per attempt, two retries after the initial attempt, and
a 30-second total request budget (`timeout`, `max_retries`, `retry_timeout`).
Timeouts and budgets must be at least 0.001 seconds. Each attempt is limited by
the remaining budget. Only HTTP 429 and 529 retry, with exponential backoff and
jitter, respecting `Retry-After` (seconds or HTTP date) and `retry-after-ms`.
Set `max_retries = 0` to disable retries. Connections and timeouts do not retry.
Redirects are not followed; the base URL must use HTTPS without user information,
query parameters or fragments.

Users may supply any model name, including a pinned version, without a model
discovery call. The actual model reported by the API will remain in the result.

## Architecture

Endpoint functions share internal helpers for validation, HTTP requests and
errors. The client is a small S3 list. `R/questions.R` and `R/system_one.R` remain
planned for step 3; the other files below are implemented.

| File | Responsibility |
| --- | --- |
| `R/client.R` | Client construction, configuration and safe printing |
| `R/questions.R` | Question constructors |
| `R/system_one.R` | Evaluation endpoint |
| `R/models.R` | Model discovery endpoint |
| `R/request.R` | Authentication, HTTP execution, timeouts and retries |
| `R/validation.R` | Input checks and JSON shape handling |
| `R/errors.R` | Package conditions and diagnostic extraction |

`typesafer` requires R >= 4.1.0 and `httr2` >= 1.2.3. The transport uses a small
retry loop to limit each attempt by the remaining total budget and to support
TypeSafe retry headers. Runtime dependencies are declared in DESCRIPTION;
`testthat` and `withr` are test dependencies.

The client will preserve server-provided values and unknown response fields.
It will not recompute confidence, round scores, renumber rubric levels or
automatically convert responses into data frames.

## Model discovery

Store `TYPESAFE_API_KEY` in your `.Renviron` and restart R before this example.
The request requires Internet access and a valid key.

```r
client <- typesafer::create_typesafe_client()
result <- typesafer::list_models(client)
result$models
```

The result is a nested list. Each model has `name`, `description` and
`release_date` strings; additional server fields are preserved.

Failures inherit from `typesafer_error`, with subclasses for invalid inputs,
HTTP failures, connection failures, timeouts and malformed responses. HTTP
errors retain `status`, `server_message` and `validation` diagnostics; printed
errors omit server content. Validation diagnostics exclude echoed inputs.
Transport errors retain sanitised underlying error classes and messages in
`causes`, without request objects.

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

Follow [AGENTS.md](AGENTS.md) and the existing `.lintr` configuration. There is
currently no CI configuration. Tests use `testthat` edition 3 and mocked
responses, without Internet access or personal credentials. Future live tests
will require both `RUN_NETWORK_TESTS=true` and an API key; ordinary
test runs will skip them. Retry tests will mock delays and responses.

From a local checkout, install dependencies and the package with
`devtools::install(dependencies = TRUE)`. For development, run from the repository
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
