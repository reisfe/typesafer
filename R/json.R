is_json_object <- function(value) {
  return(is.list(value) && !is.object(value) && !is.null(names(value)))
}

has_valid_names <- function(value) {
  value_names <- names(value)
  return(!is.null(value_names) && !anyNA(value_names) &&
           all(nzchar(value_names)) && !anyDuplicated(value_names))
}

validate_json_value <- function(value, argument) {
  if (is.null(value))
    return(invisible(NULL))

  if (length(setdiff(names(attributes(value)), "names")) > 0L ||
      !typeof(value) %in% c("list", "character", "logical", "integer", "double"))
    abort_typesafer(paste0("`", argument, "` contains an unsupported R value; ",
                           "use plain lists, strings, logicals or finite numbers."),
                    "typesafer_input_error")

  if (is.list(value)) {
    if (!is.null(names(value)) && !has_valid_names(value))
      abort_typesafer(paste0("`", argument, "` contains invalid list names; ",
                             "object names must be unique, non-empty and non-missing."),
                      "typesafer_input_error")
    for (entry in value) validate_json_value(entry, argument)
  } else {
    if (anyNA(value) || (is.numeric(value) && any(!is.finite(value))))
      abort_typesafer(paste0("`", argument, "` contains missing or non-finite values."),
                      "typesafer_input_error")
  }

  return(invisible(NULL))
}

is_entry_value <- function(value, allow_null = TRUE) {
  if (is.null(value))
    return(allow_null)
  else if (is.list(value))
    return(TRUE)
  else if (is.character(value) && length(value) == 1L)
    return(TRUE)
  else
    return(is.atomic(value) && length(value) != 1L)
}

validate_entry_value <- function(value, argument, allow_null = TRUE) {
  validate_json_value(value, argument)
  if (!is_entry_value(value, allow_null)) {
    message <- paste0("`", argument, "` must be a string, object or array")
    if (allow_null) message <- paste0(message, ", or NULL")
    abort_typesafer(paste0(message, "."), "typesafer_input_error")
  }
  return(invisible(NULL))
}

normalize_json_value <- function(value) {
  if (is.null(value))
    return(NULL)
  else if (is.list(value))
    return(lapply(value, normalize_json_value))
  else if (length(value) == 1L)
    return(unname(value))
  else
    return(as.list(unname(value)))
}

serialize_json_body <- function(body) {
  validate_json_value(body, "request body")
  normalized <- normalize_json_value(body)
  # Lists retain array/object shape even when an array has only one element.
  json <- jsonlite::toJSON(normalized, auto_unbox = TRUE, null = "null", digits = 22)
  return(enc2utf8(as.character(json)))
}
