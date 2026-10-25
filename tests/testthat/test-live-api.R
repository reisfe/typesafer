create_live_test_client <- function() {
  testthat::skip_if(
    Sys.getenv("RUN_NETWORK_TESTS") != "true",
    "Live API tests disabled; set RUN_NETWORK_TESTS=true to enable.")
  if (!nzchar(trimws(Sys.getenv("TYPESAFE_API_KEY"))))
    stop("Live API tests require TYPESAFE_API_KEY when RUN_NETWORK_TESTS=true.",
         call. = FALSE)
  return(create_typesafe_client())
}

create_live_test_questions <- function() {
  return(list(
    urgent = create_noul_question("Does this message express urgency?"),
    department = create_choice_question(
      criteria = list(billing = "Payments and invoices", technical = "Software issues"),
      instructions = "Which department should handle this message?"),
    frustration = create_score_question(
      criteria = c("Calm", "Frustrated", "Angry"),
      instructions = "How frustrated does the customer seem?")))
}

expect_live_evaluation <- function(result, questions) {
  testthat::expect_type(result$model, "character")
  testthat::expect_length(result$model, 1L)
  testthat::expect_true(nzchar(result$model))
  testthat::expect_setequal(names(result$answers), names(questions))
  for (field in c("input_tokens", "output_tokens")) {
    value <- result$usage[[field]]
    testthat::expect_true(is.numeric(value) && length(value) == 1L &&
                            is.finite(value) && value >= 0 && value == floor(value))
  }

  for (name in names(questions)) {
    question <- questions[[name]]
    answer <- result$answers[[name]]
    testthat::expect_identical(answer$type, question$type)
    if (question$type == "noul") {
      testthat::expect_true(is.numeric(answer$noul) && length(answer$noul) == 1L &&
                              is.finite(answer$noul) &&
                              answer$noul >= 0 && answer$noul <= 1)
    } else {
      testthat::expect_true(is.numeric(answer$confidence) &&
                              length(answer$confidence) == 1L &&
                              is.finite(answer$confidence) &&
                              answer$confidence >= 0 && answer$confidence <= 1)
      if (question$type == "choice") {
        keys <- names(question$criteria)
        testthat::expect_true(answer$choice %in% keys)
      } else {
        keys <- as.character(seq_along(question$criteria) - 1L)
        testthat::expect_setequal(names(answer$legend), keys)
        testthat::expect_true(is.numeric(answer$score) && length(answer$score) == 1L &&
                                is.finite(answer$score) &&
                                answer$score >= 0 && answer$score <= length(keys) - 1L)
      }
      testthat::expect_setequal(names(answer$probabilities), keys)
      for (probability in answer$probabilities)
        testthat::expect_true(is.numeric(probability) && length(probability) == 1L &&
                                is.finite(probability) &&
                                probability >= 0 && probability <= 1)
    }
  }
  return(invisible(NULL))
}

testthat::test_that("live API returns available models", {
  client <- create_live_test_client()
  result <- list_models(client)
  testthat::expect_type(result$models, "list")
  testthat::expect_gt(length(result$models), 0L)
  for (model in result$models) {
    for (field in c("name", "description", "release_date")) {
      testthat::expect_type(model[[field]], "character")
      testthat::expect_length(model[[field]], 1L)
      testthat::expect_false(is.na(model[[field]]))
    }
    testthat::expect_true(nzchar(model$name))
    testthat::expect_true(nzchar(model$release_date))
  }
})

for (question_name in c("urgent", "department", "frustration")) {
  testthat::test_that(paste("live API evaluates a single", question_name, "question"), {
    client <- create_live_test_client()
    questions <- create_live_test_questions()[question_name]
    result <- evaluate_questions(
      client,
      state = "I was charged twice. Please fix this today.",
      questions = questions)
    expect_live_evaluation(result, questions)
  })
}

testthat::test_that("live API evaluates mixed questions against structured state", {
  client <- create_live_test_client()
  questions <- create_live_test_questions()
  result <- evaluate_questions(
    client,
    state = list(message = "I was charged twice. Please fix this today."),
    questions = questions)
  expect_live_evaluation(result, questions)
})
