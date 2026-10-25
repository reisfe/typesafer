testthat::test_that("invalid successful response bodies fail without leaking content", {
  responses <- list(
    create_test_response(200L, "private content"),
    create_test_response(200L, "null"),
    create_test_response(200L, "[]"),
    create_test_response(200L, '"private content"'),
    httr2::response(status_code = 200L, headers = list(`content-type` = "text/html"),
                    body = charToRaw('{"private content":true}')),
    create_test_response(204L, ""))

  for (response in responses) {
    for (endpoint in c("models", "evaluation")) {
      calls <- 0L
      error <- httr2::with_mocked_responses(function(req) {
        calls <<- calls + 1L
        return(response)
      }, tryCatch({
        if (endpoint == "models") {
          list_models(create_test_client())
        } else {
          evaluate_questions(create_test_client(), "text", create_test_questions())
        }
      }, typesafer_error = identity))
      testthat::expect_s3_class(error, "typesafer_response_error")
      testthat::expect_identical(calls, 1L)
      testthat::expect_false(
        any(grepl("private content", capture.output(str(error)), fixed = TRUE)))
    }
  }
})

testthat::test_that("evaluation response fields require exact names at every level", {
  fixture <- jsonlite::fromJSON(read_evaluation_fixture(), simplifyVector = FALSE)
  paths <- list(
    c("model"), c("answers"), c("usage"), c("usage", "input_tokens"),
    c("usage", "output_tokens"), c("answers", "is_urgent", "noul"),
    c("answers", "department", "choice"), c("answers", "department", "confidence"),
    c("answers", "department", "probabilities"), c("answers", "severity", "score"),
    c("answers", "severity", "legend"), c("answers", "severity", "type"))

  for (path in paths) {
    bad <- fixture
    field <- tail(path, 1L)
    if (length(path) == 1L) {
      names(bad)[names(bad) == field] <- paste0(field, "_backup")
    } else {
      parent <- head(path, -1L)
      value <- bad[[parent]]
      names(value)[names(value) == field] <- paste0(field, "_backup")
      bad[[parent]] <- value
    }
    httr2::with_mocked_responses(list(create_evaluation_response(bad)), {
      testthat::expect_error(
        evaluate_questions(create_test_client(), "text", create_test_questions()),
        class = "typesafer_response_error")
    })
  }
})

testthat::test_that("duplicate rubric map keys and invalid output counts are rejected", {
  fixture <- jsonlite::fromJSON(read_evaluation_fixture(), simplifyVector = FALSE)
  for (field in c("probabilities", "legend")) {
    bad <- fixture
    bad$answers$severity[[field]] <- c(bad$answers$severity[[field]],
                                       bad$answers$severity[[field]][1L])
    httr2::with_mocked_responses(list(create_evaluation_response(bad)), {
      testthat::expect_error(
        evaluate_questions(create_test_client(), "text", create_test_questions()),
        class = "typesafer_response_error")
    })
  }

  for (count in list(NULL, -1, 0.5, "1", list(1))) {
    bad <- fixture
    bad$usage["output_tokens"] <- list(count)
    httr2::with_mocked_responses(list(create_evaluation_response(bad)), {
      testthat::expect_error(
        evaluate_questions(create_test_client(), "text", create_test_questions()),
        class = "typesafer_response_error")
    })
  }
})

testthat::test_that("maximum rubrics and probability boundaries survive full request", {
  choices <- setNames(rep(list(NULL), 255L), paste0("option_", seq_len(255L)))
  levels <- paste("Level", seq_len(10L))
  questions <- list(
    yes = create_noul_question("Is this true?"),
    no = create_noul_question("Is this false?"),
    choice = create_choice_question(choices),
    low = create_score_question(levels), high = create_score_question(levels))
  probabilities <- setNames(as.list(c(1, rep(0, 9L))), as.character(0:9))
  legend <- setNames(as.list(levels), as.character(0:9))
  low <- list(type = "score", score = 0, confidence = 0,
              probabilities = probabilities, legend = legend)
  high <- list(type = "score", score = 9, confidence = 1,
               probabilities = setNames(rev(unname(probabilities)), names(probabilities)),
               legend = legend)
  response <- list(
    model = "resolved",
    answers = list(
      high = high, low = low,
      choice = list(
        type = "choice",
        choice = "option_255",
        confidence = 1,
        probabilities = setNames(as.list(c(rep(0, 254L), 1)), names(choices))),
      no = list(type = "noul", noul = 0), yes = list(type = "noul", noul = 1)),
    usage = list(input_tokens = 0L, output_tokens = 0L))

  result <- httr2::with_mocked_responses(function(req) {
    decoded <- jsonlite::fromJSON(read_request_body(req), simplifyVector = FALSE)
    testthat::expect_identical(decoded$questions$choice$criteria, choices)
    testthat::expect_identical(decoded$questions$high$criteria, as.list(levels))
    return(create_evaluation_response(response))
  }, evaluate_questions(create_test_client(), list(), questions))

  testthat::expect_equal(result, response)
  testthat::expect_identical(names(result$answers), names(response$answers))
})

testthat::test_that("a single Choice option keeps its object and probability map", {
  questions <- list(one = create_choice_question(list(only = NULL)))
  response <- list(model = "resolved", answers = list(one = list(
    type = "choice", choice = "only", confidence = 0, probabilities = list(only = 1))),
    usage = list(input_tokens = 0L, output_tokens = 0L))
  result <- httr2::with_mocked_responses(function(req) {
    testthat::expect_match(read_request_body(req),
                           '"criteria":{"only":null}',
                           fixed = TRUE)
    return(create_evaluation_response(response))
  }, evaluate_questions(create_test_client(), "text", questions))
  testthat::expect_equal(result, response)
})
