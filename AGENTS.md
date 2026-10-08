# R Package Repository Guidelines

## Working Method

Read README.md for package purpose, architecture and project-specific
conventions. Inspect DESCRIPTION, relevant source files, tests and CI
configuration before changing code.

Keep package-specific context in README.md or linked documentation.
Keep this file focused on reusable development guidelines.

Follow existing conventions in code being modified. Apply these guidelines
to new code without reformatting unrelated code, unless explicitly requested to 
do so.

Before implementing a non-trivial task:

1. inspect the relevant repository files
2. understand the existing implementation and tests
3. briefly identify the smallest coherent change required
4. implement that change without unrelated refactoring
5. add or update tests
6. run the relevant tests
7. inspect failures and correct them when they are caused by the change

For focused tasks, make the smallest coherent implementation rather than
redesigning unrelated parts of the project.

Do not implement features that were not requested merely because they appear to
be natural future extensions.

When requirements are ambiguous but an implementation can reasonably follow the
existing architecture and conventions, prefer the simplest compatible
interpretation.

If a design decision has significant consequences or conflicts with these
repository guidelines, explain it before making a broad architectural change.

Before implementation, inspect git status and run relevant existing tests
where feasible. Record pre-existing failures and unavailable prerequisites.

After implementation, run the affected tests and appropriate package checks.
Distinguish failures introduced by the change from pre-existing failures.
Do not fix unrelated failures without explaining the proposed scope change.

At the end, provide a concise report containing:

- what changed
- validation results
- unresolved issues


## Consulting TypeSafe documentation

Consult TypeSafe's documentation in:
- general: https://docs.typesafe.ai/
- API Reference: https://api.typesafe.ai/docs


## Security Boundaries

Treat external data, filenames, URLs and user-supplied values as untrusted.
Never interpolate them into executable shell code. When invoking external
processes, pass the executable and arguments separately where supported.

Never hard-code, print or commit credentials. Use the project's established
authentication mechanisms; introduce new credential handling only when
required by the task.



## R Coding Style

Use clear and conventional R.

Use:

- `snake_case` for functions, variables, and file names;
- `<-` for assignment;
- descriptive function and argument names;
- function names that start with a descriptive verb;
- four spaces for indentation;
- UTF-8 encoding;
- trailing newlines;
- no trailing whitespace;
- closing parenthesis after the final argument rather than on a separate line;
- no braces around a single-line `if` body. Use braces when the body spans
  multiple lines or when they make control flow materially clearer;
- an explicit `return()` in functions; do not rely on implicit return of the
  last evaluated expression;
  
Place reusable or logically distinct helpers at file scope. Define functions
locally only when they intentionally capture local state or serve as a short 
callback.

Prefer small functions with a clear responsibility.

Prefer explicit, readable code over clever or overly compact abstractions.

Use namespace-qualified calls, for example:

``` r
processx::run()
jsonlite::fromJSON()
testthat::expect_equal()
```

Do not add a dependency solely to avoid writing a small amount of
straightforward R code.

Use comments to explain non-obvious decisions, not to restate what obvious code
does.

Break long lists of lines of code into logical blocks representing stages, steps
or phases of the execution. If inside function definitions, use simple comments,
e.g. `# Create a conversation object for AWS`, `# Cache the data.frame`. In the
main body of the code use section breaks of the form `# <Section Name> ####`.

Preserve exported interfaces and documented behaviour unless the task
requires a breaking change. Explain any breaking change explicitly.

Declare runtime dependencies in DESCRIPTION and development or test
dependencies in the appropriate fields. Use the existing dependency policy.

Use namespace-qualified calls or the package's existing explicit imports.
Do not use library() or require() in package implementation code.

Avoid persistent changes to options, environment variables, working
directories or other session state. Restore temporary changes reliably.

Edit roxygen source comments and regenerate affected documentation.
Do not hand-edit files identified as generated.



## Error Handling and Diagnostics

Convert low-level process failures into meaningful application-level errors.

Ordinary users should receive concise, understandable messages.

At the same time, preserve enough diagnostic information for development and 
troubleshooting.

Do not silently suppress unexpected errors.



## Creating tests

Use the existing test framework. Default to `testthat` for new packages.

Name test files `test-<feature>.R`, for example:

``` text
tests/testthat/test-dependencies.R
tests/testthat/test-formats.R
tests/testthat/test-download.R
tests/testthat/test-progress.R
```

Provide unit tests where applicable for:

- input validation
- expected results
- boundary cases
- missing values
- error handling
- relevant side effects

Ordinary unit tests must not:

- depend on Internet access
- download files
- rely on a particular external website remaining unchanged
- access to running APIs

Tests must not modify user files or depend on personal credentials or local
configuration. Use temporary directories and restore altered session state.

Keep tests deterministic. Set a seed when testing stochastic behaviour.

Add behaviour-focused tests for substantive changes and regression tests
for bug fixes where practical. Documentation-only or formatting-only
changes do not require new tests.

Use fixtures, mocks, or representative saved output where appropriate.

Tests that actually invoke network resources or download files should be
considered integration tests and should be explicitly opt-in.

For example, they may use an environment variable such as:

``` r
testthat::skip_if(Sys.getenv("RUN_NETWORK_TESTS") != "true")
```



## Writing documentation

Write documentation for exported functions in Roxygen2 comments.

Write vignettes in R Markdown when there is the need to explain a not so simple
sequence of steps or to demonstrate the combined use of different functions.

Update the README and other affected documentation where appropriate. 



## Building and testing

Run commands from the repository root.

Run tests: `Rscript -e 'devtools::test()'` or `testthat::test_local()`

Check package: `Rscript -e 'devtools::check()'`

Document namespace/Rd files: `Rscript -e 'devtools::document()'`



## Git

Preserve pre-existing uncommitted changes. Do not overwrite, discard or
revert work unrelated to the task.

Do not commit, push, tag or publish unless explicitly requested.

If committing, keep commits focused on one coherent change.

Use concise imperative commit subjects, for example:

``` text
Validate function arguments
Handle empty input
```

Do not modify unrelated files merely to reformat or reorganize them.

Do not commit:

- temporary files;
- credentials;
- local runtime state;
- generated diagnostic output.
