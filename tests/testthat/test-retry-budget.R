testthat::test_that("an expired initial budget prevents any HTTP request", {
    elapsed <- 0
    testthat::local_mocked_bindings(get_elapsed_time = function() {
        elapsed <<- elapsed + 1
        return(elapsed)
    })
    httr2::with_mocked_responses(function(req) stop("Unexpected HTTP call"), {
        testthat::expect_error(list_models(create_test_client(retry_timeout = 1)),
                               "budget was exhausted", class = "typesafer_timeout_error")
    })
})

testthat::test_that("budget expiry during a response or wait preserves the last HTTP error", {
    for (stage in c("response", "wait")) {
        elapsed <- 0
        calls <- 0L
        waits <- 0L
        testthat::local_mocked_bindings(get_elapsed_time = function() elapsed,
                                        wait_for_retry = function(seconds) {
                                            waits <<- waits + 1L
                                            elapsed <<- elapsed + 2
                                            return(invisible(NULL))
                                        })
        error <- httr2::with_mocked_responses(function(req) {
            calls <<- calls + 1L
            if (stage == "response") elapsed <<- elapsed + 2
            return(create_test_response(529L, headers = list(`Retry-After` = "0")))
        }, tryCatch(list_models(create_test_client(retry_timeout = 1)), typesafer_error = identity))
        testthat::expect_s3_class(error, "typesafer_http_error")
        testthat::expect_identical(error$status, 529L)
        testthat::expect_identical(calls, 1L)
        testthat::expect_identical(waits, if (stage == "wait") 1L else 0L)
    }
})

testthat::test_that("a delay equal to the remaining budget does not sleep or retry", {
    testthat::local_mocked_bindings(get_elapsed_time = function() 0,
                                    wait_for_retry = function(seconds) stop("Unexpected wait"))
    calls <- 0L
    httr2::with_mocked_responses(function(req) {
        calls <<- calls + 1L
        return(create_test_response(429L, headers = list(`Retry-After` = "1")))
    }, testthat::expect_error(list_models(create_test_client(retry_timeout = 1)),
                              "HTTP 429", class = "typesafer_http_error"))
    testthat::expect_identical(calls, 1L)
})

testthat::test_that("retry headers have explicit precedence and deterministic HTTP dates", {
    now <- as.POSIXct("2026-10-09 12:00:00", tz = "GMT")
    testthat::local_mocked_bindings(Sys.time = function() now, .package = "base")
    testthat::expect_equal(parse_retry_after("Fri, 09 Oct 2026 12:01:00 GMT"), 60)
    testthat::expect_equal(parse_retry_after("Fri, 09 Oct 2026 11:59:00 GMT"), 0)
    for (value in c("Inf", "NaN", "-1", "bad", "Fri, 09 Xxx 2026 12:00:00 GMT",
                    "Fri, 32 Oct 2026 12:00:00 GMT")) {
        testthat::expect_true(is.na(parse_retry_after(value)))
    }
    testthat::expect_true(is.na(parse_retry_after(NULL)))
    response <- create_test_response(headers = list(`Retry-After` = "2", `retry-after-ms` = "500"))
    testthat::expect_equal(get_retry_delay(response, 1L), 2)
    response <- create_test_response(headers = list(`Retry-After` = "bad", `retry-after-ms` = "500"))
    testthat::expect_equal(get_retry_delay(response, 1L), 0.5)
    response <- create_test_response(headers = list(`retry-after-ms` = "0"))
    testthat::expect_equal(get_retry_delay(response, 1L), 0)
})
