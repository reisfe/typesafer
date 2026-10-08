create_test_questions <- function() {
    urgent <- create_noul_question("Does this message express urgency?")
    department <- create_choice_question(list(billing = NULL, technical = list(description = "Bugs")),
                                         instructions = list(task = "Which department?", references = list("single")))
    severity <- create_score_question(list("Calm", list(level = "Frustrated"), list("Angry", "Severe")))
    return(list(is_urgent = urgent, department = department, severity = severity))
}

read_evaluation_fixture <- function() {
    path <- testthat::test_path("fixtures", "evaluation.json")
    return(paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
}

create_evaluation_response <- function(result = NULL) {
    if (is.null(result)) return(create_test_response(body = read_evaluation_fixture()))
    body <- jsonlite::toJSON(result, auto_unbox = TRUE, null = "null", digits = 22)
    return(create_test_response(body = as.character(body)))
}

read_request_body <- function(request) {
    body <- request$body$data
    if (is.raw(body)) body <- rawToChar(body)
    return(body)
}
