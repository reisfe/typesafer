testthat::test_that("HTTP errors preserve selected diagnostics without printing server content", {
    body <- paste0('{"detail":[{"loc":["body","model"],"msg":"Invalid test-key",',
                   '"type":"invalid","input":"private content","ctx":{"key":"test-key"}}]}')
    for (status in c(400L, 401L, 403L, 422L, 429L, 500L, 529L, 302L)) {
        error <- httr2::with_mocked_responses(
                                              list(create_test_response(status, body)),
                                              tryCatch(list_models(create_test_client(max_retries = 0)),
                                                       typesafer_error = identity))
        testthat::expect_s3_class(error, "typesafer_http_error")
        testthat::expect_equal(error$status, status)
        testthat::expect_identical(error$validation[[1L]]$location, c("body", "model"))
        testthat::expect_identical(error$validation[[1L]]$message, "Invalid [REDACTED]")
        testthat::expect_false(grepl("Invalid", conditionMessage(error)))
        testthat::expect_false(any(grepl("test-key|private content", capture.output(str(error)))))
    }
    error <- httr2::with_mocked_responses(
                                          list(create_test_response(400L, '{"detail":"Bad Bearer other-key test-key"}')),
                                          tryCatch(list_models(create_test_client()), typesafer_error = identity))
    testthat::expect_identical(error$server_message, "Bad Bearer [REDACTED] [REDACTED]")
    httr2::with_mocked_responses(list(create_test_response(502L, '<html>private</html>')), {
        testthat::expect_error(list_models(create_test_client()), "HTTP 502",
                               class = "typesafer_http_error")
    })
})

testthat::test_that("connection failures and timeouts are classified without retrying", {
    for (kind in c("curl_error_couldnt_resolve_host", "curl_error_operation_timedout")) {
        calls <- 0L
        parent <- structure(list(message = "Failure with test-key", call = NULL),
                            class = c(kind, "error", "condition"))
        failure <- structure(list(message = "HTTP failure", call = NULL, parent = parent,
                                  request = list(api_key = "test-key")),
                             class = c("httr2_failure", "error", "condition"))
        error <- httr2::with_mocked_responses(function(req) {
            calls <<- calls + 1L
            stop(failure)
        }, tryCatch(list_models(create_test_client()), typesafer_error = identity))
        expected <- if (kind == "curl_error_operation_timedout")
            "typesafer_timeout_error" else "typesafer_connection_error"
        testthat::expect_s3_class(error, expected)
        testthat::expect_identical(calls, 1L)
        testthat::expect_identical(error$causes[[2L]]$class, c(kind, "error", "condition"))
        testthat::expect_false(any(grepl("test-key", capture.output(str(error)))))
    }
})

testthat::test_that("unexpected programming errors are not converted to connection errors", {
    httr2::with_mocked_responses(function(req) stop("Unexpected failure"), {
        testthat::expect_error(list_models(create_test_client()), "Unexpected failure")
    })
})

testthat::test_that("only 429 and 529 retry and server delays are respected", {
    waits <- numeric()
    testthat::local_mocked_bindings(get_elapsed_time = function() 0,
                                    wait_for_retry = function(seconds) {
                                        waits <<- c(waits, seconds)
                                        return(invisible(NULL))
                                    })
    calls <- 0L
    responses <- list(
                      create_test_response(429L, headers = list(`Retry-After` = "2")),
                      create_test_response(529L, headers = list(`retry-after-ms` = "500")),
                      create_test_response())
    result <- httr2::with_mocked_responses(function(req) {
        calls <<- calls + 1L
        return(responses[[calls]])
    }, list_models(create_test_client()))
    testthat::expect_identical(calls, 3L)
    testthat::expect_equal(waits, c(2, 0.5))
    testthat::expect_identical(result$models[[1L]]$name, "jev-latest")

    for (status in c(400L, 401L, 422L, 500L, 503L)) {
        calls <- 0L
        httr2::with_mocked_responses(function(req) {
            calls <<- calls + 1L
            return(create_test_response(status))
        }, testthat::expect_error(list_models(create_test_client()),
                                  class = "typesafer_http_error"))
        testthat::expect_identical(calls, 1L)
    }
})

testthat::test_that("retry exhaustion and disabling retries preserve the last HTTP error", {
    testthat::local_mocked_bindings(get_elapsed_time = function() 0,
                                    wait_for_retry = function(seconds) invisible(NULL))
    for (retries in c(0L, 2L)) {
        calls <- 0L
        httr2::with_mocked_responses(function(req) {
            calls <<- calls + 1L
            return(create_test_response(529L, headers = list(`Retry-After` = "0")))
        }, testthat::expect_error(list_models(create_test_client(max_retries = retries)),
                                  "HTTP 529", class = "typesafer_http_error"))
        testthat::expect_equal(calls, retries + 1L)
    }
})

testthat::test_that("the time budget prevents excessive delays and limits attempt timeouts", {
    testthat::local_mocked_bindings(get_elapsed_time = function() 0,
                                    wait_for_retry = function(seconds) stop("Must not wait beyond budget"))
    calls <- 0L
    httr2::with_mocked_responses(function(req) {
        calls <<- calls + 1L
        testthat::expect_lte(req$options$timeout_ms, 1000)
        return(create_test_response(429L, headers = list(`Retry-After` = "60")))
    }, testthat::expect_error(list_models(create_test_client(retry_timeout = 1)),
                              "HTTP 429", class = "typesafer_http_error"))
    testthat::expect_identical(calls, 1L)
})

testthat::test_that("attempt timeouts shrink with time spent requesting and waiting", {
    elapsed <- 0
    testthat::local_mocked_bindings(get_elapsed_time = function() elapsed,
                                    wait_for_retry = function(seconds) {
                                        elapsed <<- elapsed + seconds
                                        return(invisible(NULL))
                                    })
    timeouts <- numeric()
    httr2::with_mocked_responses(function(req) {
        timeouts <<- c(timeouts, req$options$timeout_ms)
        elapsed <<- elapsed + 1
        if (length(timeouts) == 1L)
            return(create_test_response(429L, headers = list(`Retry-After` = "1")))
        return(create_test_response())
    }, list_models(create_test_client(retry_timeout = 3)))
    testthat::expect_equal(timeouts, c(3000, 1000))
})

testthat::test_that("retry headers and jittered backoff handle boundary cases", {
    withr::local_seed(123)
    testthat::expect_equal(parse_retry_after("0"), 0)
    testthat::expect_true(is.na(parse_retry_after("invalid")))
    testthat::expect_true(is.na(parse_retry_after("-1")))
    for (attempt in c(1L, 2L, 100L)) {
        response <- create_test_response(headers = list(`Retry-After` = "bad",
                                                        `retry-after-ms` = "-1"))
        delay <- get_retry_delay(response, attempt)
        testthat::expect_gte(delay, 0)
        testthat::expect_lte(delay, min(60, 2^min(attempt, 6)))
    }
})
