#' Create typed TypeSafe questions
#'
#' Constructors return ordinary lists and make no network calls. They omit
#' optional fields when their arguments are `NULL`. Manually assembled question
#' lists can retain named `NULL` elements to send explicit JSON nulls.
#'
#' @param instructions A string, JSON object (named list) or array (unnamed list
#'   or multi-element atomic vector). Optional if criteria suffice.
#' @param criteria For Noul, an optional named list with `true` and/or `false`
#'   descriptions. Non-empty instructions or a non-null recognised criterion
#'   is required. For Choice, a named list of 1 to 255 option descriptions.
#'   For Score, an unnamed list or character vector of 1 to 10 ordered level
#'   descriptions; a character vector is always treated as an array, including
#'   when it has one element. Score level numbers start at zero. Two or more
#'   levels are recommended. Descriptions can be strings, objects or arrays;
#'   Noul and Choice descriptions can also be `NULL`.
#' @return An ordinary list with `type`, and any supplied `instructions` and
#'   `criteria`, suitable for [evaluate_questions()]. Invalid input raises
#'   `typesafer_input_error` without echoing submitted values.
#' @rdname create_questions
#' @export
#' @examples
#' create_noul_question("Does this message express urgency?")
#' create_choice_question(list(billing = "Payments", technical = "Bugs"))
#' create_score_question(c("Calm", "Frustrated", "Angry"))
create_noul_question <- function(instructions = NULL, criteria = NULL) {
  return(create_question("noul", instructions, criteria))
}

#' @rdname create_questions
#' @export
create_choice_question <- function(criteria, instructions = NULL) {
  if (missing(criteria))
    abort_typesafer("`criteria` is required for Choice question.",
                    "typesafer_input_error")
  return(create_question("choice", instructions, criteria))
}

#' @rdname create_questions
#' @export
create_score_question <- function(criteria, instructions = NULL) {
  if (missing(criteria))
    abort_typesafer("`criteria` is required for Score question.", "typesafer_input_error")
  return(create_question("score", instructions, criteria))
}

create_question <- function(type, instructions, criteria) {
  question <- list(type = type)
  if (!is.null(instructions)) question$instructions <- instructions
  if (!is.null(criteria) || type != "noul") question["criteria"] <- list(criteria)
  return(validate_question(question))
}

has_question_content <- function(value) {
  if (is.null(value) || length(value) == 0L) return(FALSE)
  if (is.character(value) && length(value) == 1L) return(nzchar(value))
  return(TRUE)
}

validate_question <- function(question) {
  validate_json_value(question, "question")
  if (!is_json_object(question) || !has_valid_names(question))
    abort_typesafer("Each question must be a named list.",
                    "typesafer_input_error")
  type <- question[["type"]]
  if (!is_scalar_string(type) || !type %in% c("noul", "choice", "score"))
    abort_typesafer("Question `type` must be 'noul', 'choice' or 'score'.",
                    "typesafer_input_error")
  instructions <- question[["instructions"]]
  criteria <- question[["criteria"]]
  validate_entry_value(instructions, "instructions")

  if (type == "noul") {
    if (!is.null(criteria) && !is_json_object(criteria))
      abort_typesafer("Noul `criteria` must be a named list or NULL.",
                      "typesafer_input_error")
    validate_entry_value(criteria[["true"]], "criteria.true")
    validate_entry_value(criteria[["false"]], "criteria.false")
    if (!has_question_content(instructions) &&
        is.null(criteria[["true"]]) &&
        is.null(criteria[["false"]])) {
      abort_typesafer(
        "Noul question requires non-empty instructions or non-null true/false criterion.",
        "typesafer_input_error")
    }
  } else if (type == "choice") {
    if (!is_json_object(criteria) || length(criteria) < 1L || length(criteria) > 255L)
      abort_typesafer("Choice `criteria` must be a named list of 1 to 255 options.",
                      "typesafer_input_error")
    for (entry in criteria) validate_entry_value(entry, "Choice criteria")
  } else {
    # The schema fixes this field as an array, even for a single level.
    if (is.character(criteria)) criteria <- as.list(unname(criteria))
    if (!is.list(criteria) || !is.null(names(criteria)) ||
        length(criteria) < 1L || length(criteria) > 10L) {
      abort_typesafer(
        "Score `criteria` must be an unnamed list or character vector of 1 to 10 levels.",
        "typesafer_input_error")
    }
    for (entry in criteria)
      validate_entry_value(entry, "Score criteria", allow_null = FALSE)
    question$criteria <- criteria
  }
  return(question)
}
