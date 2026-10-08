# TypeSafe API contract for typesafer

This document records the initial implementation contract agreed on
8 October 2026. It separates published schemas, observed service behaviour and
R mappings. Both API endpoints, client configuration, transport and all three
question constructors are implemented.

## Sources and verification

- [General documentation](https://docs.typesafe.ai/)
- [HTTP API reference](https://docs.typesafe.ai/api)
- [OpenAPI schema](https://api.typesafe.ai/openapi.json), reporting API metadata
  version `0.2.0` when reviewed
- [Structured inputs](https://docs.typesafe.ai/primitives/advanced)
- [Models](https://docs.typesafe.ai/models)
- [Confidence](https://docs.typesafe.ai/confidence)
- [SDK configuration](https://docs.typesafe.ai/sdk/python/api/constants)
- [SDK retry policy](https://docs.typesafe.ai/sdk/python/api/retries)

Authenticated probes were run from R on 8 October 2026 using synthetic content
and the key already available as `TYPESAFE_API_KEY`. Credentials and submitted
inputs were excluded from diagnostic output. Successful evaluations using
`jev-latest` reported `jev-1.13.0`. These observations describe that service at
that time; they are not guarantees about future models or API versions.

## HTTP operations

Base URL: `https://api.typesafe.ai`. Both endpoints require
`Authorization: Bearer <API_KEY>`. Evaluation uses a JSON request body.

| Method and path | Request | Successful response |
| --- | --- | --- |
| `GET /v1/models` | No body | `models`: array of objects containing `name`, `description`, `release_date` |
| `POST /v1/systemone` | Required `state`, `model`, `questions` | Required `model`, `answers`, `usage` |

Model discovery returned `jev-latest` and `jev-preview` during verification.
The client must not treat discovery as exhaustive validation: published model
guidance allows versioned IDs even when discovery does not list them.

`state` accepts a string, JSON object or array. `model` is a string.
`questions` is a non-empty object mapping user-chosen names to question objects.
Questions are evaluated independently against the same state; this is one
state with many questions, not a batch of independent requests.

## Questions and answers

Every question has a `type` discriminator. Instructions can be a string,
object, array or null, and may be omitted subject to the Noul rule below.

| Type | Criteria | Answer fields |
| --- | --- | --- |
| `noul` | Optional object with `true` and/or `false` descriptions | `type`, `noul` |
| `choice` | Object mapping option names to descriptions | `type`, `choice`, `confidence`, `probabilities` |
| `score` | Ordered array of level descriptions | `type`, `score`, `confidence`, `legend`, `probabilities` |

Choice descriptions and Noul criterion descriptions accept strings, objects,
arrays or null. Score descriptions accept strings, objects or arrays.

Noul returns the probability of yes/true, between zero and one, without a
separate confidence field. Choice returns the highest-probability option and
the probability of each option. Score returns a probability-weighted expected
value over levels numbered from zero; the value may be fractional. Score
legend and probability keys are strings such as `"0"` and `"1"`.

Choice and Score include confidence between zero and one. Preserve confidence
and probabilities as received rather than deriving or normalising them.

`answers` is keyed by the original question names, with matching question
types. The response includes the actual `model` and `usage`, containing
`input_tokens` and `output_tokens`.

## Documentation/schema discrepancies and live results

The prose reference marks instructions as required, while OpenAPI allows
omission or null. OpenAPI specifies at least one Score level, but omits the
documented upper bounds and the non-empty Choice constraint.

| Probe | Observed result |
| --- | --- |
| Choice instructions omitted / null, with valid criteria | HTTP 200 for both |
| Score instructions omitted / null, with valid criteria | HTTP 200 for both |
| Noul instructions omitted / null, without criteria | HTTP 400 for both: requires criteria or instructions |
| Noul with criteria only | HTTP 200 |
| Noul with instructions only | HTTP 200 |
| Noul empty string / array / object instructions, without criteria | HTTP 400 for each |
| Noul empty criteria object or null-only recognised criteria | HTTP 400 |
| Noul unknown criterion only | HTTP 400 |
| Noul empty string / array / object `true` description | HTTP 200 for each |
| Noul with only a non-null `false` criterion | HTTP 200 |
| Noul empty instructions with a valid `true` criterion | HTTP 200 |
| Score with zero levels | HTTP 422: at least one item required |
| Score with 1, 2 or 10 levels | HTTP 200 |
| Score with 11 levels | HTTP 400: at most 10 levels |
| Score with a null level | HTTP 422 |
| Choice with zero options | HTTP 400: at least one choice required |
| Choice with 1 or 255 options | HTTP 200 |
| Choice with 256 options | HTTP 400: at most 255 choices |

Local validation permits optional instructions, accepts 1–10 Score levels
and accepts 1–255 Choice options. Noul requires non-empty instructions or a
non-null recognised `true`/`false` criterion. Empty criterion descriptions
(strings, arrays or objects) count as supplied; nulls and unknown fields do not. At least two Score levels remain the documentation's recommendation,
not an enforced service minimum. A one-option Choice is also accepted even
though it is of limited practical use.

The additional empty-value and null-level probes above were performed during
step 3 on 8 October 2026. Score null levels are rejected by the service and
OpenAPI even though the general structured-input page includes null among Score
entry shapes. The client follows the verified service behaviour. Unknown
question fields are preserved when they contain supported JSON values.

## R and JSON mappings

| R representation | JSON representation |
| --- | --- |
| Scalar character value | String |
| Named list with unique, non-empty names | Object |
| Unnamed list | Array, including a one-element array |
| Atomic vector with multiple elements | Array of scalar values; vector names ignored |
| Character vector used as Score criteria | Array of descriptions, even for one element |
| `list()` | Empty array |
| `structure(list(), names = character())` | Empty object |
| `NULL` retained as a named list element | Explicit null |
| Field absent from a list | Omitted property |

Scalar numeric and logical values are permitted inside structured JSON.
Top-level state and description values must follow their documented shapes.
Use a one-element unnamed list when a JSON array is required for one value.
The distinction between explicit null and an omitted property survives
serialization. Optional constructor arguments defaulting to `NULL` omit their
field; manually assembled lists can express explicit nulls. Serialization uses
`jsonlite` directly, with explicit nulls and sufficient numeric precision,
before passing the JSON body to the shared HTTP transport.

Reject `NA`, `NaN`, infinite numbers, duplicate or partial list names, and
unsupported R objects rather than silently coercing them. Data frames, factors,
dates and other classed objects require explicit conversion to supported
values in this initial interface. No automatic row-wise evaluation is planned.

Responses are decoded into nested lists without simplifying arrays into
data frames. Preserve API names, zero-based legend keys, nulls and unknown
fields. Model release dates remain strings. Validate essential response
structure and report malformed responses without rejecting harmless additions.
Evaluation checks matching answer names and types, probability maps, zero-based
rubric keys, score/confidence/probability ranges and non-negative integer token
counts. It does not require an exact probability sum, recompute scores or
confidence, or reorder answers. Model overrides apply to one request only.

## Errors and retries

Published guidance documents HTTP 401 for authentication failure, 422 for
schema validation, 429 for rate limiting and 529 for overload. Live probes also
demonstrated HTTP 400 for application-level validation. Handle other non-success
statuses through a general HTTP error condition rather than assuming this list
is exhaustive.

Package conditions distinguish HTTP failures, connection failures,
timeouts and malformed responses. HTTP conditions should retain status,
server messages and validation locations. Do not automatically print request
content, credentials or echoed invalid inputs. Preserve underlying causes for
troubleshooting without silently suppressing unexpected failures.

Use bounded exponential backoff with jitter for HTTP 429 and 529, honouring
server retry headers when supplied. Expose retry limits and allow retries to
be disabled. Initially do not automatically replay evaluation requests after
ambiguous connection failures or timeouts. Do not retry authentication or
validation failures. Configure retryable statuses explicitly in the transport
rather than relying on the HTTP library's defaults.

Transport defaults are a 10-second timeout per attempt, two retries after the
initial attempt and a 30-second total budget. Timeout and budget values must be
at least 0.001 seconds. Each attempt uses the smaller of the configured timeout
and remaining budget. A delay that consumes the remaining budget stops retries
and returns the last HTTP error. `Retry-After` accepts seconds or IMF-fixdate;
`retry-after-ms` is a fallback. Invalid headers fall back to jittered exponential
backoff capped at 60 seconds. Redirects are not followed. Do not hard-code
changing model rate limits or context budgets as universal client constraints.

## Verification strategy

Translate these shapes and observed boundaries into offline fixtures and
regression tests as functions are implemented. Test serialization, response
preservation and errors independently of network access. Optional live tests
must require `RUN_NETWORK_TESTS=true` and credentials, use synthetic inputs and
report the model version. No live probes run during ordinary checks.
