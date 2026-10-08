abort_typesafer <- function(message, subclass, ...) {
    condition <- structure(list(message = message, call = NULL, ...),
                           class = c(subclass, "typesafer_error", "error", "condition"))
    stop(condition)
}

redact_diagnostic <- function(message, api_key) {
    message <- gsub(api_key, "[REDACTED]", message, fixed = TRUE)
    return(gsub("(?i)Bearer[[:space:]]+[^[:space:]\"']+",
                "Bearer [REDACTED]", message, perl = TRUE))
}

collect_error_causes <- function(error, api_key) {
    causes <- list()
    while (inherits(error, "condition")) {
        cause <- list(class = class(error),
                      message = redact_diagnostic(conditionMessage(error), api_key))
        causes[[length(causes) + 1L]] <- cause
        error <- error$parent
    }
    return(causes)
}

is_timeout_error <- function(error) {
    while (inherits(error, "condition")) {
        if (inherits(error, "curl_error_operation_timedout")) return(TRUE)
        error <- error$parent
    }
    return(FALSE)
}

abort_transport_error <- function(error, api_key) {
    if (is_timeout_error(error)) {
        abort_typesafer("The TypeSafe request timed out.", "typesafer_timeout_error",
                        causes = collect_error_causes(error, api_key))
    }
    return(abort_typesafer("Could not connect to or read from the TypeSafe API.",
                           "typesafer_connection_error",
                           causes = collect_error_causes(error, api_key)))
}

abort_http_error <- function(response, api_key) {
    status <- httr2::resp_status(response)
    messages <- c(`400` = "The TypeSafe API rejected the request.",
                  `401` = "TypeSafe authentication failed; check your API key.",
                  `403` = "The TypeSafe API denied access.",
                  `422` = "The TypeSafe request failed validation.",
                  `429` = "The TypeSafe API rate limit was reached.",
                  `529` = "The TypeSafe API is temporarily overloaded.")
    message <- unname(messages[as.character(status)])
    if (is.na(message)) message <- "The TypeSafe API request failed."

    # Extract only diagnostic fields; never retain the request or echoed input.
    body <- tryCatch(httr2::resp_body_json(response, check_type = FALSE),
                     error = function(error) NULL)
    server_message <- NULL
    validation <- list()
    if (is.list(body) && !is.null(names(body))) {
        if (is.character(body$detail))
            server_message <- redact_diagnostic(body$detail, api_key)
        if (is.character(body$message))
            server_message <- redact_diagnostic(body$message, api_key)
        if (is.list(body$detail)) {
            for (entry in body$detail) {
                if (!is.list(entry)) next
                location <- entry$loc
                if (is.list(location)) location <- unlist(location, use.names = FALSE)
                if (!is.character(location) && !is.numeric(location)) location <- NULL
                diagnostic <- list(location = redact_diagnostic(as.character(location), api_key),
                                   message = if (is.character(entry$msg))
                                       redact_diagnostic(entry$msg, api_key) else NULL,
                                   type = if (is.character(entry$type))
                                       redact_diagnostic(entry$type, api_key) else NULL)
                validation[[length(validation) + 1L]] <- diagnostic
            }
        }
    }
    return(abort_typesafer(paste0(message, " (HTTP ", status, ")."),
                           "typesafer_http_error", status = status,
                           server_message = server_message, validation = validation))
}
