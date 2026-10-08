#' Create a TypeSafe API client
#'
#' Configuration is resolved from explicit arguments, then environment
#' variables, then defaults. Construction makes no network request and does
#' not modify the R environment or read configuration files directly.
#'
#' @param api_key API key. Defaults to `TYPESAFE_API_KEY`; required.
#' @param base_url HTTPS API base URL, optionally including a path prefix.
#'   Defaults to `TYPESAFE_BASE_URL`, or `https://api.typesafe.ai` when unset.
#'   User information, query parameters and fragments are not accepted.
#' @param model Default model name. Defaults to `TYPESAFE_DEFAULT_MODEL`, or
#'   `jev-latest` when unset. No discovery request is required to validate it.
#' @param timeout Timeout in seconds for each HTTP attempt, at least 0.001.
#' @param max_retries Non-negative integer number of retries after the initial
#'   attempt. Only HTTP 429 and 529 are retried. Zero disables retries.
#' @param retry_timeout Total time budget in seconds, at least 0.001, including all
#'   attempts and retry delays. Each attempt is limited by the remaining budget.
#' @return A `typesafe_client` S3 list containing resolved configuration. The
#'   key is stored in memory; printing the client hides its configuration.
#' @export
#' @examples
#' client <- create_typesafe_client(api_key = "example-key")
#' print(client)
create_typesafe_client <- function(
    api_key = Sys.getenv("TYPESAFE_API_KEY"),
    base_url = Sys.getenv("TYPESAFE_BASE_URL", "https://api.typesafe.ai"),
    model = Sys.getenv("TYPESAFE_DEFAULT_MODEL", "jev-latest"),
    timeout = 10, max_retries = 2L, retry_timeout = 30)
{
    validate_client_settings(api_key, base_url, model, timeout,
                             max_retries, retry_timeout)
    client <- list(api_key = api_key, base_url = sub("/+$", "", base_url),
                   model = model, timeout = timeout, max_retries = max_retries,
                   retry_timeout = retry_timeout)
    return(structure(client, class = "typesafe_client"))
}

#' Print a TypeSafe client
#'
#' Prints a summary without showing the API key or other configuration values.
#' @param x A TypeSafe client.
#' @param ... Unused arguments.
#' @return The client, invisibly.
#' @export
print.typesafe_client <- function(x, ...) {
    cat("<typesafe_client>\nConfiguration hidden; API key stored in memory.\n")
    return(invisible(x))
}
