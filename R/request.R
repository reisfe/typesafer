build_typesafe_request <- function(client, method, path, body = NULL) {
    validate_client(client)
    request <- httr2::request(client$base_url)
    request <- httr2::req_url_path_append(request, path)
    request <- httr2::req_method(request, method)
    request <- httr2::req_auth_bearer_token(request, client$api_key)
    request <- httr2::req_headers(request, Accept = "application/json")
    request <- httr2::req_user_agent(request, "typesafer R API client")
    request <- httr2::req_options(request, followlocation = FALSE)
    request <- httr2::req_error(request, is_error = function(response) FALSE)
    if (!is.null(body))
        request <- httr2::req_body_json(request, body, auto_unbox = TRUE, null = "null")
    return(request)
}

get_elapsed_time <- function() {
    return(unname(proc.time()["elapsed"]))
}

wait_for_retry <- function(seconds) {
    Sys.sleep(seconds)
    return(invisible(NULL))
}

parse_retry_after <- function(value) {
    if (is.null(value)) return(NA_real_)
    seconds <- suppressWarnings(as.numeric(value))
    if (length(seconds) == 1L && is.finite(seconds) && seconds >= 0)
        return(seconds)

    # Parse IMF-fixdate independently of the user's LC_TIME locale.
    pattern <- "^[A-Za-z]{3}, ([0-9]{2}) ([A-Za-z]{3}) ([0-9]{4}) ([0-9]{2}:[0-9]{2}:[0-9]{2}) GMT$"
    parts <- regmatches(value, regexec(pattern, value))[[1L]]
    if (length(parts) != 5L) return(NA_real_)
    month <- match(parts[3L], c("Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"))
    if (is.na(month)) return(NA_real_)
    timestamp <- as.POSIXct(paste0(parts[4L], "-", month, "-", parts[2L],
                                   " ", parts[5L]),
                            format = "%Y-%m-%d %H:%M:%S", tz = "GMT")
    if (is.na(timestamp)) return(NA_real_)
    return(max(0, as.numeric(difftime(timestamp, Sys.time(), units = "secs"))))
}

get_retry_delay <- function(response, attempt) {
    seconds <- parse_retry_after(httr2::resp_header(response, "Retry-After"))
    if (!is.na(seconds)) return(seconds)
    milliseconds <- httr2::resp_header(response, "retry-after-ms")
    if (!is.null(milliseconds)) {
        milliseconds <- suppressWarnings(as.numeric(milliseconds))
        if (is.finite(milliseconds) && milliseconds >= 0)
            return(milliseconds / 1000)
    }
    return(stats::runif(1L, min = 0, max = min(60, 2^min(attempt, 6))))
}

perform_typesafe_request <- function(client, method, path, body = NULL) {
    request <- build_typesafe_request(client, method, path, body)
    deadline <- get_elapsed_time() + client$retry_timeout
    attempt <- 0L
    repeat {
        remaining <- min(client$retry_timeout, deadline - get_elapsed_time())
        if (remaining < 0.001) {
            if (attempt > 0L) abort_http_error(response, client$api_key)
            abort_typesafer("The TypeSafe request time budget was exhausted.",
                            "typesafer_timeout_error")
        }
        timed_request <- httr2::req_timeout(request, min(client$timeout, remaining))
        response <- tryCatch(httr2::req_perform(timed_request, verbosity = 0),
                             httr2_failure = function(error)
                                 abort_transport_error(error, client$api_key))
        attempt <- attempt + 1L
        status <- httr2::resp_status(response)
        if (status >= 200L && status < 300L) break
        if (!status %in% c(429L, 529L) || attempt > client$max_retries)
            abort_http_error(response, client$api_key)
        delay <- get_retry_delay(response, attempt)
        if (delay >= deadline - get_elapsed_time())
            abort_http_error(response, client$api_key)
        wait_for_retry(delay)
    }
    result <- tryCatch(httr2::resp_body_json(response, simplifyVector = FALSE),
                       error = function(error) {
                           message <- "The TypeSafe API returned an invalid JSON response."
                           return(abort_typesafer(message, "typesafer_response_error",
                                                  status = status))
                       })
    if (!is.list(result) || is.null(names(result)))
        abort_typesafer("The TypeSafe API returned an unexpected response structure.",
                        "typesafer_response_error", status = status)
    return(result)
}
