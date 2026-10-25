# typesafer

`typesafer` is an R package in development for accessing the TypeSafe AI API.
The package provides a thin, synchronous client that maps the HTTP API to R
functions and preserves its request and response structures.

## Status and scope

Both API endpoints and all three question constructors are implemented, along
with client configuration and shared transport. Offline tests cover input
validation boundaries, JSON shapes and precision, response preservation,
malformed responses, retry exhaustion and credential redaction. Regression
review is complete; CI remains for step 5.

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

The following functions are implemented:

| Function | Responsibility |
| --- | --- |
| `create_typesafe_client()` | Create a lightweight S3 client holding configuration |
| `list_models(client)` | Retrieve available models and aliases |
| `evaluate_questions(client, state, questions, model)` | Evaluate named questions against one state |
| `create_noul_question(instructions = NULL, criteria = NULL)` | Construct a Noul question |
| `create_choice_question(criteria, instructions = NULL)` | Construct a Choice question |
| `create_score_question(criteria, instructions = NULL)` | Construct a Score question |

Question constructors return ordinary lists. Evaluation also accepts manually
assembled question lists with the same structure. Endpoint functions return
nested lists with API field names unchanged.

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
questions to TypeSafe. Client settings default
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
errors. The client is a small S3 list. All files below are implemented.

| File | Responsibility |
| --- | --- |
| `R/client.R` | Client construction, configuration and safe printing |
| `R/questions.R` | Question constructors |
| `R/system_one.R` | Evaluation endpoint |
| `R/models.R` | Model discovery endpoint |
| `R/request.R` | Authentication, HTTP execution, timeouts and retries |
| `R/validation.R` | Client configuration checks |
| `R/json.R` | JSON validation, shape mapping and serialization |
| `R/errors.R` | Package conditions and diagnostic extraction |

`typesafer` requires R >= 4.1.0, `httr2` >= 1.2.3 and `jsonlite` >= 1.8.0.
JSON encoding is explicit so arrays, objects, nulls and numeric precision can
be verified in the request body. The transport uses a small retry loop to limit
each attempt by the remaining total budget and to support TypeSafe retry
headers. Runtime dependencies are declared in DESCRIPTION; `testthat` and
`withr` are test dependencies.

The client preserves server-provided values and unknown response fields.
It does not recompute confidence, round scores, renumber rubric levels or
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

## Evaluation

With the same configured client, mix question types in one request:

```r
questions <- list(
    urgent = typesafer::create_noul_question("Does this message express urgency?"),
    department = typesafer::create_choice_question(
        criteria = list(billing = "Payments and invoices", technical = "Software issues"),
        instructions = "Which department should handle this?"),
    frustration = typesafer::create_score_question(
        criteria = c("Calm", "Frustrated", "Angry"),
        instructions = "How frustrated does the customer seem?"))

result <- typesafer::evaluate_questions(
    client,
    state = list(message = "I was charged twice. Please fix this today."),
    questions = questions)

result$answers$department$choice
result$answers$frustration$score
result$model
result$usage
```

The model and probabilities can vary. Noul returns a probability of yes/true.
Choice returns the selected option and all option probabilities. Score returns
a probability-weighted score over levels numbered from zero, so scores can be
fractional. Choice and Score also include confidence.

A request may override the client's model with `model = "versioned-model-id"`
without changing the client or calling model discovery.

## Input and JSON conventions

Use plain named lists for JSON objects and unnamed lists for JSON arrays.
Atomic vectors with multiple elements become arrays, with vector names ignored.
Use `list("one")` for a singleton array; `"one"` is a scalar string. Score
character criteria always become an array, even for one level.

`list()` represents an empty array and
`structure(list(), names = character())` represents an empty object. Named
`NULL` list elements represent explicit JSON nulls. Constructors omit optional
fields whose arguments are `NULL`; manually assembled questions can include
explicit nulls. JSON objects require unique, non-empty, non-missing names.

Convert data frames, factors, dates and matrices explicitly to supported plain
values. Missing values (`NA`/`NaN`), infinite numbers and other unsupported R
objects are rejected before sending a request.

Choice requires 1–255 options and Score requires 1–10 levels (at least two
recommended). Score descriptions cannot be null. Noul requires non-empty
instructions or a non-null `true`/`false` criterion; an empty criterion
description is accepted by the API. See the [API contract](docs/api-contract.md)
for the verified boundary cases.

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
currently no CI configuration. Unit tests use `testthat` edition 3 and mocked
responses, without Internet access or personal credentials. Retry tests mock
delays and responses, with fixed clocks for budget and HTTP-date checks.

Live integration tests are in `tests/testthat/test-live-api.R` and run through
the same test framework. By default, they skip with an informative message.
They run only when `RUN_NETWORK_TESTS` is exactly `"true"`; an enabled run fails
if `TYPESAFE_API_KEY` is missing or blank. They use the normal client settings,
including `TYPESAFE_BASE_URL` and `TYPESAFE_DEFAULT_MODEL` when configured.

The live tests make five requests before any retries: model discovery, one
evaluation per question type, and a mixed evaluation with structured state.
They send only synthetic content and check response contracts and valid ranges,
without asserting exact predictions, probabilities or model versions. They
require Internet access and may incur API charges. API errors, timeouts and
incompatible responses fail the tests rather than being skipped.

From a local checkout, install dependencies and the package with
`devtools::install(dependencies = TRUE)`. For development, run from the repository
root:

```r
devtools::document()
devtools::test()
devtools::check()
```

To run live tests, configure `TYPESAFE_API_KEY` in your `.Renviron`, restart R,
and run the following from the repository root. To include live tests alongside
the offline suite:

```r
withr::with_envvar(
  c(RUN_NETWORK_TESTS = "true"),
  devtools::test())
```

To run only the live tests:

```r
withr::with_envvar(
  c(RUN_NETWORK_TESTS = "true"),
  devtools::test(filter = "^live-api$"))
```

The temporary setting is restored after the run. Leave the flag unset for
ordinary offline tests and package checks.

Edit roxygen comments in source files and regenerate documentation and exports.
Keep changes focused and preserve existing work.

## References and license

- [TypeSafe general documentation](https://docs.typesafe.ai/)
- [HTTP API reference](https://docs.typesafe.ai/api)
- [Swagger API reference](https://api.typesafe.ai/docs)
- [OpenAPI schema](https://api.typesafe.ai/openapi.json)

Licensed under GPL-3, as declared in [DESCRIPTION](DESCRIPTION).
