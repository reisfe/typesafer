create_test_questions <- function() {
  urgent_question <- create_noul_question(
    instructions = "Does this message express urgency?")

  department_question <- create_choice_question(
    criteria = list(
      billing = NULL,
      technical = list(description = "Bugs")),
    instructions = list(
      task = "Which department?",
      references = list("single")))

  severity_question <- create_score_question(
    criteria = list(
      "Calm",
      list(level = "Frustrated"),
      list("Angry", "Severe")))

  test_questions <- list(
    is_urgent = urgent_question,
    department = department_question,
    severity = severity_question)

  return(test_questions)
}

read_evaluation_fixture <- function() {
  fixture <- testthat::test_path("fixtures", "evaluation.json") |>
    readLines(warn = FALSE, encoding = "UTF-8") |>
    paste(collapse = "\n")

  return(fixture)
}

create_evaluation_response <- function(result = NULL) {
  if (is.null(result))
    response <- create_test_response(
      body = read_evaluation_fixture())
  else
    response <- create_test_response(
      body = jsonlite::toJSON(result, auto_unbox = TRUE, null = "null", digits = 22))

  return(response)
}

read_request_body <- function(request) {
  body <- request$body$data
  if (is.raw(body))
    body <- rawToChar(body)
  return(body)
}
