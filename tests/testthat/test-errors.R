testthat::test_that("only exact diagnostic field names are extracted", {
  body <- paste0('{"message_backup":"Unexpected",',
                 '"detail":[{"loc_backup":["body","state"],',
                 '"msg_backup":"Unexpected","type_backup":"unexpected"}]}')
  error <- httr2::with_mocked_responses(
    list(create_test_response(422L, body)),
    tryCatch(list_models(create_test_client()), typesafer_error = identity))
  testthat::expect_s3_class(error, "typesafer_http_error")
  testthat::expect_null(error$server_message)
  testthat::expect_identical(error$validation,
                             list(list(location = character(),
                                       message = NULL, type = NULL)))
})

testthat::test_that("retained HTTP diagnostic fields redact keys and bearer tokens", {
  key <- "test.+[key]"
  secret <- paste(key, key, "bEaReR unrelated-token")
  body <- jsonlite::toJSON(list(message = secret, detail = list(list(
    loc = list("body", secret, 0L), msg = secret, type = secret,
    input = "private input", ctx = list(secret = "private context")))), auto_unbox = TRUE)
  client <- create_typesafe_client(api_key = key)
  error <- httr2::with_mocked_responses(
    list(create_test_response(422L, as.character(body))),
    tryCatch(list_models(client), typesafer_error = identity))
  testthat::expect_s3_class(error, "typesafer_http_error")
  testthat::expect_identical(error$server_message,
                             "[REDACTED] [REDACTED] Bearer [REDACTED]")
  testthat::expect_identical(error$validation[[1L]]$location,
                             c("body", error$server_message, "0"))
  testthat::expect_identical(error$validation[[1L]]$message, error$server_message)
  testthat::expect_identical(error$validation[[1L]]$type, error$server_message)
  diagnostic <- paste(capture.output(str(error)), collapse = "\n")
  for (value in c(key, "unrelated-token", "private input", "private context"))
    testthat::expect_false(grepl(value, diagnostic, fixed = TRUE))
  testthat::expect_false(grepl("REDACTED", conditionMessage(error), fixed = TRUE))
  testthat::expect_null(error$call)
  testthat::expect_null(error$request)
})

testthat::test_that("malformed server diagnostics still produce concise HTTP errors", {
  bodies <- c("not JSON", "null", "[]", '"private content"',
              '{"detail":[null,3,"private content"]}',
              '{"message":3,"detail":[{"loc":true,"msg":false,"type":3}]}')
  for (body in bodies) {
    error <- httr2::with_mocked_responses(
      list(create_test_response(400L, body)),
      tryCatch(list_models(create_test_client()), typesafer_error = identity))
    testthat::expect_s3_class(error, "typesafer_http_error")
    testthat::expect_identical(error$status, 400L)
    testthat::expect_null(error$server_message)
    testthat::expect_false(any(grepl("private content",
                                     capture.output(str(error)), fixed = TRUE)))
  }
})

testthat::test_that("error chains retain classes but discard requests and calls", {
  key <- "test.+[key]"
  parent <- structure(list(
    message = paste("Failure", key, "bearer other-token"),
    call = quote(secret_call()),
    request = list(body = "private content")),
    class = c("curl_error_couldnt_connect", "error", "condition"))
  failure <- structure(list(
    message = paste(key, key),
    parent = parent,
    call = quote(secret_call())),
    class = c("httr2_failure", "error", "condition"))
  error <- httr2::with_mocked_responses(
    function(req) stop(failure),
    tryCatch(list_models(create_typesafe_client(api_key = key)),
             typesafer_error = identity))

  testthat::expect_s3_class(error, "typesafer_connection_error")
  testthat::expect_identical(error$causes[[1L]]$message, "[REDACTED] [REDACTED]")
  testthat::expect_identical(error$causes[[2L]]$message,
                             "Failure [REDACTED] Bearer [REDACTED]")
  testthat::expect_identical(error$causes[[2L]]$class, class(parent))
  testthat::expect_identical(lapply(error$causes, names),
                             rep(list(c("class", "message")), 2L))
  diagnostic <- paste(capture.output(str(error)), collapse = "\n")
  for (value in c(key, "other-token", "private content", "secret_call"))
    testthat::expect_false(grepl(value, diagnostic, fixed = TRUE))
})
