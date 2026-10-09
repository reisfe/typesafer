testthat::test_that("client construction resolves configuration without network access", {
    withr::local_envvar(c(TYPESAFE_API_KEY = "environment-key",
                          TYPESAFE_BASE_URL = "https://example.org/prefix/",
                          TYPESAFE_DEFAULT_MODEL = "custom-model"))
    httr2::with_mocked_responses(function(req) stop("Unexpected HTTP call"), {
        client <- create_typesafe_client()
        testthat::expect_s3_class(client, "typesafe_client")
        testthat::expect_identical(client$api_key, "environment-key")
        testthat::expect_identical(client$base_url, "https://example.org/prefix")
        testthat::expect_identical(client$model, "custom-model")
        testthat::expect_equal(client$timeout, 10)
        testthat::expect_equal(client$max_retries, 2)
        testthat::expect_equal(client$retry_timeout, 30)
        explicit <- create_typesafe_client("explicit-key", "https://other.org", "pinned")
        testthat::expect_identical(explicit$api_key, "explicit-key")
        testthat::expect_identical(explicit$base_url, "https://other.org")
        testthat::expect_identical(explicit$model, "pinned")
        testthat::expect_error(create_typesafe_client(api_key = ""),
                               class = "typesafer_input_error")
    })
    withr::local_envvar(c(TYPESAFE_BASE_URL = NA, TYPESAFE_DEFAULT_MODEL = NA))
    defaults <- create_typesafe_client(api_key = "test-key")
    testthat::expect_identical(defaults$base_url, "https://api.typesafe.ai")
    testthat::expect_identical(defaults$model, "jev-latest")
})

testthat::test_that("required client settings do not partially match other fields", {
    for (field in c("api_key", "base_url", "model", "timeout", "max_retries", "retry_timeout")) {
        client <- create_test_client()
        names(client)[names(client) == field] <- paste0(field, "_backup")
        httr2::with_mocked_responses(function(req) stop("Unexpected HTTP call"), {
            testthat::expect_error(list_models(client), class = "typesafer_input_error")
        })
    }
})

testthat::test_that("missing and malformed configuration is rejected without exposing values", {
    withr::local_envvar(c(TYPESAFE_API_KEY = NA))
    testthat::expect_error(create_typesafe_client(), "TYPESAFE_API_KEY",
                           class = "typesafer_input_error")
    for (key in list(NULL, NA_character_, character(), c("a", "b"), " ", "bad\nkey")) {
        testthat::expect_error(create_typesafe_client(api_key = key),
                               class = "typesafer_input_error")
    }
    for (url in c("", "http://example.org", "https://", "https://user:secret@host",
                  "https://host?key=secret", "https://host#secret", "https://host/ bad")) {
        testthat::expect_error(create_test_client(base_url = url),
                               class = "typesafer_input_error")
    }
    for (value in list(NULL, NA_real_, Inf, -1, 0, 0.0001, "10", c(1, 2))) {
        testthat::expect_error(create_test_client(timeout = value),
                               class = "typesafer_input_error")
        testthat::expect_error(create_test_client(retry_timeout = value),
                               class = "typesafer_input_error")
    }
    for (value in list(NULL, NA_real_, Inf, -1, 0.5, "2", c(1, 2))) {
        testthat::expect_error(create_test_client(max_retries = value),
                               class = "typesafer_input_error")
    }
    testthat::expect_error(create_test_client(model = NA_character_),
                           class = "typesafer_input_error")
    testthat::expect_error(create_test_client(model = ""),
                           class = "typesafer_input_error")
    withr::local_envvar(c(TYPESAFE_BASE_URL = "", TYPESAFE_DEFAULT_MODEL = ""))
    testthat::expect_error(create_typesafe_client(api_key = "test-key"),
                           class = "typesafer_input_error")
})

testthat::test_that("printing a client hides all configured values", {
    client <- create_typesafe_client("private-key", "https://private.example", "private-model")
    output <- capture.output(testthat::expect_identical(print(client), client))
    testthat::expect_match(paste(output, collapse = "\n"), "typesafe_client")
    testthat::expect_false(any(grepl("private", output)))
    invisible_output <- capture.output(visibility <- withVisible(print(client)))
    testthat::expect_false(visibility$visible)
})

testthat::test_that("client calls preserve environment variables and session options", {
    withr::local_envvar(c(TYPESAFE_API_KEY = "test-key", TYPESAFE_BASE_URL = NA,
                          TYPESAFE_DEFAULT_MODEL = NA))
    variables <- c("TYPESAFE_API_KEY", "TYPESAFE_BASE_URL", "TYPESAFE_DEFAULT_MODEL")
    environment <- Sys.getenv(variables, unset = NA_character_)
    client <- create_typesafe_client()
    original <- client
    settings <- options()
    httr2::with_mocked_responses(list(create_test_response()), list_models(client))
    testthat::expect_identical(options(), settings)
    httr2::with_mocked_responses(list(create_test_response(401L)), {
        testthat::expect_error(list_models(client), class = "typesafer_http_error")
    })
    testthat::expect_identical(options(), settings)
    testthat::expect_identical(Sys.getenv(variables, unset = NA_character_), environment)
    testthat::expect_identical(client, original)
})
