testthat::test_that("mixed evaluation sends one POST and preserves the complete server response", {
    client <- create_test_client(model = "configured-pinned")
    questions <- create_test_questions()
    original <- questions
    calls <- 0L
    result <- httr2::with_mocked_responses(function(req) {
        calls <<- calls + 1L
        testthat::expect_identical(req$method, "POST")
        testthat::expect_identical(req$url, "https://api.typesafe.ai/v1/systemone")
        testthat::expect_identical(req$body$content_type, "application/json")
        json <- read_request_body(req)
        testthat::expect_match(json, '"state":["A calm message."]', fixed = TRUE)
        testthat::expect_match(json, '"billing":null', fixed = TRUE)
        testthat::expect_match(json, '"references":["single"]', fixed = TRUE)
        decoded <- jsonlite::fromJSON(json, simplifyVector = FALSE)
        testthat::expect_identical(decoded$model, "configured-pinned")
        testthat::expect_identical(decoded$questions, questions)
        return(create_evaluation_response())
    }, evaluate_questions(client, list("A calm message."), questions))
    expected <- jsonlite::fromJSON(read_evaluation_fixture(), simplifyVector = FALSE)
    testthat::expect_identical(result, expected)
    testthat::expect_identical(calls, 1L)
    testthat::expect_identical(questions, original)
    testthat::expect_identical(client$model, "configured-pinned")
    testthat::expect_identical(names(result$answers), c("severity", "department", "is_urgent"))
    testthat::expect_identical(result$answers$severity$score, 1.7)
    testthat::expect_identical(result$answers$department$confidence, 0.37)
    testthat::expect_identical(result$answers$department$probabilities$billing, 0.799999999)
    testthat::expect_null(result$answers$is_urgent$confidence)
    testthat::expect_true("future" %in% names(result$answers$severity))
})

testthat::test_that("manual lists preserve explicit nulls and normalize Score arrays", {
    questions <- list(
                      is_urgent = list(type = "noul", instructions = NULL, criteria = list(true = "Urgent")),
                      department = list(type = "choice", instructions = NULL,
                                        criteria = list(billing = NULL, technical = "Bugs"), future = list(value = NULL)),
                      severity = list(type = "score", criteria = c("Calm", "Frustrated", "Angry")))
    original <- questions
    client <- create_test_client(model = "configured")
    httr2::with_mocked_responses(function(req) {
        json <- read_request_body(req)
        testthat::expect_match(json, '"instructions":null', fixed = TRUE)
        testthat::expect_match(json, '"criteria":["Calm","Frustrated","Angry"]', fixed = TRUE)
        testthat::expect_match(json, '"future":{"value":null}', fixed = TRUE)
        decoded <- jsonlite::fromJSON(json, simplifyVector = FALSE)
        testthat::expect_identical(decoded$model, "custom-version")
        testthat::expect_identical(decoded$state, list(message = "A calm message."))
        return(create_evaluation_response())
    }, evaluate_questions(client, list(message = "A calm message."), questions, model = "custom-version"))
    testthat::expect_identical(questions, original)
    testthat::expect_identical(client$model, "configured")
})

testthat::test_that("single questions, singleton rubrics and unusual names keep their shape", {
    name <- enc2utf8("\u00e9quipe technique")
    question <- create_score_question("Only level")
    answer <- list(type = "score", score = 0, confidence = 1,
                   legend = setNames(list("Only level"), "0"),
                   probabilities = setNames(list(1), "0"))
    response <- list(model = "resolved-version", answers = setNames(list(answer), name),
                     usage = list(input_tokens = 0L, output_tokens = 0L))
    questions <- setNames(list(question), name)
    httr2::with_mocked_responses(function(req) {
        json <- read_request_body(req)
        testthat::expect_match(json, '"criteria":["Only level"]', fixed = TRUE)
        decoded <- jsonlite::fromJSON(json, simplifyVector = FALSE)
        testthat::expect_identical(names(decoded$questions), name)
        testthat::expect_identical(decoded$state$message, enc2utf8("Caf\u00e9\nquoted \"text\""))
        return(create_evaluation_response(response))
    }, evaluate_questions(create_test_client(), list(message = enc2utf8("Caf\u00e9\nquoted \"text\"")), questions))
})

testthat::test_that("invalid evaluation inputs are rejected before the network is used", {
    questions <- create_test_questions()
    client <- create_test_client()
    httr2::with_mocked_responses(function(req) stop("Unexpected HTTP call"), {
        testthat::expect_error(evaluate_questions(client), class = "typesafer_input_error")
        testthat::expect_error(evaluate_questions(client, "text"), class = "typesafer_input_error")
        for (state in list(NULL, NA_character_, 1, TRUE, Inf, factor("x"),
                           data.frame(x = "x"), list(nested = NA_real_))) {
            testthat::expect_error(evaluate_questions(client, state, questions),
                                   class = "typesafer_input_error")
        }
        for (model in list(NULL, "", NA_character_, c("one", "two"))) {
            testthat::expect_error(evaluate_questions(client, "text", questions, model),
                                   class = "typesafer_input_error")
        }
        for (value in list(NULL, list(), unname(questions), list(a = questions[[1L]], a = questions[[1L]]),
                           setNames(list(questions[[1L]]), ""),
                           setNames(list(questions[[1L]]), NA_character_),
                           list(one = list(types = "noul", instructions = "Is this urgent?")),
                           list(one = list(type = "unknown")), list(one = list(type = "noul")))) {
            testthat::expect_error(evaluate_questions(client, "text", value),
                                   class = "typesafer_input_error")
        }
        testthat::expect_error(evaluate_questions(list(), "text", questions),
                               class = "typesafer_input_error")
    })
})

testthat::test_that("evaluation rejects missing or mismatched envelope fields", {
    fixture <- jsonlite::fromJSON(read_evaluation_fixture(), simplifyVector = FALSE)
    variants <- list(
                     list(field = "model", value = NULL), list(field = "model", value = 1),
                     list(field = "model", value = ""), list(field = "model", value = list("jev")),
                     list(field = "answers", value = NULL), list(field = "answers", value = list()),
                     list(field = "answers", value = unname(fixture$answers)),
                     list(field = "answers", value = fixture$answers[1L]),
                     list(field = "answers", value = c(fixture$answers, list(extra = fixture$answers[[1L]]))),
                     list(field = "answers", value = setNames(fixture$answers, rep("same", 3L))),
                     list(field = "usage", value = NULL), list(field = "usage", value = list()),
                     list(field = "usage", value = list(input_tokens = 1)),
                     list(field = "usage", value = list(input_tokens = -1, output_tokens = 1)),
                     list(field = "usage", value = list(input_tokens = 1.5, output_tokens = 1)),
                     list(field = "usage", value = list(input_tokens = "1", output_tokens = 1)))
    for (variant in variants) {
        bad <- fixture
        bad[variant$field] <- list(variant$value)
        httr2::with_mocked_responses(list(create_evaluation_response(bad)), {
            testthat::expect_error(evaluate_questions(create_test_client(), "text", create_test_questions()),
                                   class = "typesafer_response_error")
        })
    }
})

testthat::test_that("malformed answer values and rubric maps raise response errors", {
    fixture <- jsonlite::fromJSON(read_evaluation_fixture(), simplifyVector = FALSE)
    invalid_fields <- list(
                           is_urgent = list(type = list(NULL, "choice"), noul = list(NULL, "0.5", -0.1, 1.1, list(0.5))),
                           department = list(type = list(NULL, "score"), choice = list(NULL, "unknown", 1),
                                             confidence = list(NULL, "0.5", -0.1, 1.1),
                                             probabilities = list(NULL, list(billing = 1),
                                                                  list(billing = "0.5", technical = 0.5),
                                                                  list(billing = -0.1, technical = 1.1))),
                           severity = list(type = list(NULL, "noul"), score = list(NULL, "1.5", -0.1, 2.1),
                                           confidence = list(NULL, -0.1, 1.1),
                                           probabilities = list(NULL, list(`1` = 0.1, `2` = 0.1, `3` = 0.8)),
                                           legend = list(NULL, list(`0` = "Calm"),
                                                         list(`0` = NULL, `1` = "Frustrated", `2` = "Angry"))))
    for (name in names(invalid_fields)) {
        for (field in names(invalid_fields[[name]])) {
            for (value in invalid_fields[[name]][[field]]) {
                bad <- fixture
                bad$answers[[name]][field] <- list(value)
                httr2::with_mocked_responses(list(create_evaluation_response(bad)), {
                    testthat::expect_error(evaluate_questions(create_test_client(), "text", create_test_questions()),
                                           class = "typesafer_response_error")
                })
            }
        }
    }
})

testthat::test_that("POST retries resend the same JSON and validation errors omit echoed inputs", {
    payloads <- character()
    testthat::local_mocked_bindings(get_elapsed_time = function() 0,
                                    wait_for_retry = function(seconds) invisible(NULL))
    httr2::with_mocked_responses(function(req) {
        payloads <<- c(payloads, read_request_body(req))
        if (length(payloads) == 1L)
            return(create_test_response(429L, headers = list(`Retry-After` = "0")))
        return(create_evaluation_response())
    }, evaluate_questions(create_test_client(), "private content", create_test_questions()))
    testthat::expect_length(payloads, 2L)
    testthat::expect_identical(payloads[[1L]], payloads[[2L]])
    body <- '{"detail":[{"loc":["body","state"],"msg":"Invalid","type":"invalid","input":"private content"}]}'
    error <- httr2::with_mocked_responses(list(create_test_response(422L, body)),
                                          tryCatch(evaluate_questions(create_test_client(), "private content", create_test_questions()),
                                                   typesafer_error = identity))
    testthat::expect_s3_class(error, "typesafer_http_error")
    testthat::expect_identical(error$validation[[1L]]$location, c("body", "state"))
    testthat::expect_false(any(grepl("private content", capture.output(str(error)))))
})

testthat::test_that("POST timeouts do not replay the request or retain its body in errors", {
    calls <- 0L
    parent <- structure(list(message = "Timeout", call = NULL),
                        class = c("curl_error_operation_timedout", "error", "condition"))
    error <- httr2::with_mocked_responses(function(req) {
        calls <<- calls + 1L
        failure <- structure(list(message = "HTTP failure", call = NULL, parent = parent, request = req),
                             class = c("httr2_failure", "error", "condition"))
        stop(failure)
    }, tryCatch(evaluate_questions(create_test_client(), "private content", create_test_questions()),
                typesafer_error = identity))
    testthat::expect_s3_class(error, "typesafer_timeout_error")
    testthat::expect_identical(calls, 1L)
    testthat::expect_false(any(grepl("private content|test-key", capture.output(str(error)))))
})
