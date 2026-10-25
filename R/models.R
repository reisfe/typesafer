#' List available TypeSafe models
#'
#' Queries a TypeSafe API client for the list of available models. The list may contain
#' aliases and need not include every accepted versioned model ID. Unknown response fields
#' are preserved.
#'
#' @param client A client created by [create_typesafe_client()].
#' @return A nested list with a `models` array of lists containing `name`,
#'   `description` and `release_date` strings. Dates are not converted.
#' @section Errors:
#' Failures inherit from `typesafer_error`. Subclasses include
#' `typesafer_input_error`, `typesafer_http_error`, `typesafer_connection_error`,
#' `typesafer_timeout_error` and `typesafer_response_error`.
#' HTTP errors contain `status`, `server_message` and `validation` fields;
#' validation entries contain `location`, `message` and `type`. Printed errors
#' omit server content. Transport errors contain sanitised `causes` with
#' underlying error classes and messages, without request objects.
#' @export
#' @examples
#' \dontrun{
#' client <- create_typesafe_client()
#' models <- list_models(client)
#' models$models
#' }
list_models <- function(client) {
  result <- perform_typesafe_request(client, "GET", "v1/models")
  valid <- is.list(result[["models"]]) && is.null(names(result[["models"]]))
  if (valid) {
    for (model in result[["models"]]) {
      if (!is.list(model) || !is_scalar_string(model[["name"]]) ||
          !is.character(model[["description"]]) || length(model[["description"]]) != 1L ||
          is.na(model[["description"]]) || !is_scalar_string(model[["release_date"]])) {
        valid <- FALSE
        break
      }
    }
  }
  if (!valid)
    abort_typesafer("The TypeSafe API returned an invalid model list.",
                    "typesafer_response_error")
  return(result)
}
