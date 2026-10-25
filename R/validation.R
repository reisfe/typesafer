is_scalar_string <- function(value) {
  return(is.character(value) && length(value) == 1L &&
           !is.na(value) && nzchar(trimws(value)))
}

is_finite_scalar <- function(value, minimum = -Inf, maximum = Inf) {
  return(is.numeric(value) && length(value) == 1L && !is.na(value) &&
           is.finite(value) && value >= minimum && value <= maximum)
}

validate_client_settings <- function(api_key, base_url, model, timeout,
                                     max_retries, retry_timeout) {
  if (!is_scalar_string(api_key) || grepl("[[:space:][:cntrl:]]", api_key))
    abort_typesafer("Supply a non-empty API key or set TYPESAFE_API_KEY.",
                    "typesafer_input_error")
  if (!is_scalar_string(base_url) || grepl("[[:space:][:cntrl:]]", base_url))
    abort_typesafer("`base_url` must be an HTTPS URL.", "typesafer_input_error")
  url <- tryCatch(httr2::url_parse(base_url), error = function(error) NULL)
  if (is.null(url) || !identical(url$scheme, "https") ||
      !is_scalar_string(url$hostname) || !is.null(url$username) ||
      !is.null(url$password) || length(url$query) > 0L ||
      !is.null(url$fragment) || grepl("[?#]", base_url)) {
    abort_typesafer(paste("`base_url` must be an HTTPS URL without user",
                          "information, query parameters or a fragment."),
                    "typesafer_input_error")
  }
  validate_model_name(model)
  validate_positive_number(timeout, "timeout")
  validate_positive_number(retry_timeout, "retry_timeout")
  validate_retry_count(max_retries)
  return(invisible(NULL))
}

validate_model_name <- function(model) {
  if (!is_scalar_string(model))
    abort_typesafer("`model` must be a non-empty string.", "typesafer_input_error")
  return(invisible(NULL))
}

validate_positive_number <- function(value, argument) {
  if (!is_finite_scalar(value, minimum = 0.001)) {
    abort_typesafer(paste0("`", argument, "` must be finite and at least 0.001 seconds."),
                    "typesafer_input_error")
  }
  return(invisible(NULL))
}

validate_retry_count <- function(max_retries) {
  if (!is_finite_scalar(max_retries, minimum = 0, maximum = .Machine$integer.max) ||
      max_retries != floor(max_retries)) {
    abort_typesafer("`max_retries` must be a non-negative integer.",
                    "typesafer_input_error")
  }
  return(invisible(NULL))
}

validate_client <- function(client) {
  if (!inherits(client, "typesafe_client") || !is.list(client))
    abort_typesafer("`client` must be created by create_typesafe_client().",
                    "typesafer_input_error")
  validate_client_settings(client[["api_key"]], client[["base_url"]], client[["model"]],
                           client[["timeout"]], client[["max_retries"]],
                           client[["retry_timeout"]])
  return(invisible(NULL))
}
