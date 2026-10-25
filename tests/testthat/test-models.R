testthat::test_that("model discovery sends authenticated request and preserves fields", {
  client <- create_test_client(base_url = "https://example.org/prefix/")
  body <- paste0('{"models":[{"name":"jev-custom","description":"",',
                 '"release_date":"2026-09-15","extra":null}],"future":{"enabled":true}}')
  result <- httr2::with_mocked_responses(function(req) {
    testthat::expect_identical(req$url, "https://example.org/prefix/v1/models")
    testthat::expect_identical(req$method, "GET")
    printed <- paste(capture.output(print(req, redact_headers = FALSE)), collapse = "\n")
    testthat::expect_match(printed, "Bearer test-key", fixed = TRUE)
    testthat::expect_identical(req$headers$Accept, "application/json")
    testthat::expect_null(req$body)
    testthat::expect_false(req$options$followlocation)
    testthat::expect_gt(req$options$timeout_ms, 0)
    testthat::expect_lte(req$options$timeout_ms, 10000)
    return(create_test_response(body = body))
  }, list_models(client))

  testthat::expect_identical(result$models[[1L]]$name, "jev-custom")
  testthat::expect_identical(result$models[[1L]]$release_date, "2026-09-15")
  testthat::expect_true("extra" %in% names(result$models[[1L]]))
  testthat::expect_null(result$models[[1L]]$extra)
  testthat::expect_true(result$future$enabled)
})

testthat::test_that("required response fields must have their exact API names", {
  bodies <- c(
    '{"models_backup":[]}',
    '{"models":[{"name_backup":"jev","description":"Model","release_date":"2026-9-15"}]}',
    '{"models":[{"name":"jev","description_backup":"Model","release_date":"2026-9-15"}]}',
    '{"models":[{"name":"jev","description":"Model","release_date_backup":"2026-9-15"}]}')

  for (body in bodies) {
    httr2::with_mocked_responses(list(
      create_test_response(body = body)), {
        testthat::expect_error(
          list_models(create_test_client()),
          class = "typesafer_response_error")
      })
  }
})

testthat::test_that("empty model arrays are accepted and malformed structures rejected", {
  empty <- httr2::with_mocked_responses(
    list(create_test_response(body = '{"models":[]}')),
    list_models(create_test_client()))

  testthat::expect_identical(empty$models, list())

  for (body in c('{}', '[]', 'null', '"text"', '{"models":null}',
                 '{"models":[{}]}', '{"models":[1]}',
                 '{"models":[{"name":1,"description":"x","release_date":"x"}]}',
                 '{"models":{"name":"jev"}}', '<html>Bad gateway</html>')) {
    httr2::with_mocked_responses(list(create_test_response(body = body)), {
      testthat::expect_error(list_models(create_test_client()),
                             class = "typesafer_response_error")
    })
  }
})

testthat::test_that("model discovery validates clients before any HTTP call", {
  httr2::with_mocked_responses(function(req) stop("Unexpected HTTP call"), {
    testthat::expect_error(list_models(list()), class = "typesafer_input_error")
    client <- create_test_client()
    client$base_url <- "http://example.org"
    testthat::expect_error(list_models(client), class = "typesafer_input_error")
  })
})
