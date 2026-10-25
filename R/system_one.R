#' Evaluate named questions against a state
#'
#' Queries a TypeSafe API client with one state and one or more independent typed
#' questions. Noul, Choice and Score can be mixed in one request.
#'
#' @param client A client created by [create_typesafe_client()].
#' @param state Content to evaluate: a string, a named list (JSON object), or an
#'   unnamed list or multi-element atomic vector (JSON array).
#' @param questions A non-empty named list of question lists, created with
#'   [create_noul_question()], [create_choice_question()], [create_score_question()]
#'   or assembled manually. Names must be unique, non-empty and non-missing.
#' @param model Model name or alias; defaults to the client's configured model.
#'   Supplying a model does not change the client or perform model discovery.
#' @return A nested list with `model`, named `answers` and `usage`. Answer names
#'   and types match the questions. Noul contains `noul`; Choice contains
#'   `choice`, `probabilities` and `confidence`; Score contains `score`, `legend`,
#'   `probabilities` and `confidence`. Scores can be fractional; rubric keys start
#'   at `"0"`. Server order, values, nulls and unknown fields are preserved.
#' @section JSON mappings:
#' Plain named lists become objects and unnamed lists become arrays. Atomic
#' vectors of length greater than one become arrays; a one-element unnamed list
#' explicitly represents a singleton array. Score character criteria always
#' become arrays. Named `NULL` elements become explicit nulls; absent elements
#' are omitted. `list()` is an empty array;
#' `structure(list(), names = character())` is an empty object.
#' Missing and non-finite values, classed objects and matrices are rejected.
#' Convert data frames, factors and dates explicitly before evaluation.
#' @section Errors:
#' Errors use the conditions documented in [list_models()]. Invalid request
#' inputs raise `typesafer_input_error` before sending any request. Missing or
#' malformed response fields raise `typesafer_response_error`. Probability
#' values are checked individually without normalising their sum or computing
#' confidence or scores locally.
#' @export
#' @examples
#' \dontrun{
#' client <- create_typesafe_client()
#' result <- evaluate_questions(client, "Please fix my payment today.", list(
#'   urgent = create_noul_question("Is this urgent?"),
#'   department = create_choice_question(list(billing = "Payments", technical = "Bugs")),
#'   frustration = create_score_question(c("Calm", "Frustrated", "Angry"))))
#' result$answers$department$choice
#' result$usage$input_tokens
#' }
evaluate_questions <- function(client, state, questions, model = client$model) {
  # Validate arguments
  validate_client(client)
  if (missing(state) || missing(questions))
    abort_typesafer("Both `state` and `questions` are required.",
                    "typesafer_input_error")
  validate_entry_value(state, "state", allow_null = FALSE)
  validate_model_name(model)
  validate_json_value(questions, "questions")
  if (!is_json_object(questions) || length(questions) == 0L)
    abort_typesafer("`questions` must be a non-empty named list.",
                    "typesafer_input_error")
  questions <- lapply(questions, validate_question)

  # Call TypeSafe API
  body <- list(state = state, model = model, questions = questions)
  result <- perform_typesafe_request(client, "POST", "v1/systemone", body)

  # Validate and return response
  validate_evaluation_response(result, questions)
  return(result)
}

is_token_count <- function(value) {
  return(is_finite_scalar(value, minimum = 0) && value == floor(value))
}

has_probability_map <- function(value, keys) {
  if (!is_json_object(value)  ||
      !has_valid_names(value) ||
      !setequal(names(value), keys))
    return(FALSE)
  else
    return(all(vapply(value, is_finite_scalar,
                      logical(1), minimum = 0, maximum = 1)))
}

is_valid_answer <- function(answer, question) {
  if (!is_json_object(answer)  ||
      !has_valid_names(answer) ||
      !identical(answer[["type"]], question[["type"]]))
    return(FALSE)
  type <- question[["type"]]
  if (type == "noul")
    return(is_finite_scalar(answer[["noul"]], 0, 1))
  if (!is_finite_scalar(answer[["confidence"]], 0, 1))
    return(FALSE)
  if (type == "choice") {
    choice <- answer[["choice"]]
    return(is.character(choice) &&
             length(choice) == 1L &&
             !is.na(choice) &&
             choice %in% names(question[["criteria"]]) &&
             has_probability_map(answer[["probabilities"]],
                                 names(question[["criteria"]])))
  }
  keys <- as.character(seq_along(question[["criteria"]]) - 1L)
  legend <- answer[["legend"]]
  return(is_finite_scalar(answer[["score"]], 0, length(keys) - 1L) &&
           has_probability_map(answer[["probabilities"]], keys) &&
           is_json_object(legend) && has_valid_names(legend) &&
           setequal(names(legend), keys) &&
           all(vapply(legend, is_entry_value, logical(1), allow_null = FALSE)))
}

validate_evaluation_response <- function(result, questions) {
  answers <- result[["answers"]]
  usage <- result[["usage"]]
  if (!has_valid_names(result) || !is_scalar_string(result[["model"]]) ||
      !is_json_object(answers) || !has_valid_names(answers) ||
      !setequal(names(answers), names(questions)) || !is_json_object(usage) ||
      !has_valid_names(usage) || !is_token_count(usage[["input_tokens"]]) ||
      !is_token_count(usage[["output_tokens"]])) {
    abort_typesafer("The TypeSafe API returned an invalid evaluation response.",
                    "typesafer_response_error")
  }
  for (name in names(questions)) {
    if (!is_valid_answer(answers[[name]], questions[[name]]))
      abort_typesafer("The TypeSafe API returned an invalid or mismatched answer.",
                      "typesafer_response_error")
  }
  return(invisible(NULL))
}
