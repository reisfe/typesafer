testthat::test_that("constructors return plain lists and omit optional NULL arguments", {
  httr2::with_mocked_responses(function(req) stop("Unexpected HTTP call"), {
    noul <- create_noul_question("Is this urgent?")
    testthat::expect_identical(noul,
                               list(type = "noul", instructions = "Is this urgent?"))
    criteria <- list(billing = NULL, technical = "Bugs")
    choice <- create_choice_question(criteria)
    testthat::expect_identical(choice, list(type = "choice", criteria = criteria))
    testthat::expect_identical(
      create_score_question("Only level"),
      list(type = "score", criteria = list("Only level")))
    testthat::expect_identical(
      create_score_question(c("Calm", "Angry"))$criteria,
      list("Calm", "Angry"))
    testthat::expect_identical(
      create_score_question(c(low = "Calm", high = "Angry"))$criteria,
      list("Calm", "Angry"))
    testthat::expect_false(is.object(choice))
    testthat::expect_identical(criteria, list(billing = NULL, technical = "Bugs"))
  })
})

testthat::test_that("Noul requires instructions or a recognised non-null criterion", {
  empty_object <- structure(list(), names = character())

  for (instructions in list(NULL, "", list(), empty_object)) {
    testthat::expect_error(
      create_noul_question(instructions),
      class = "typesafer_input_error")
    testthat::expect_identical(
      create_noul_question(instructions, list(true = "Calm"))$criteria,
      list(true = "Calm"))
  }

  for (criteria in list(NULL, empty_object, list(true = NULL), list(other = "Calm"))) {
    testthat::expect_error(
      create_noul_question(criteria = criteria),
      class = "typesafer_input_error")
  }

  for (value in list("Calm", "", list(), empty_object)) {
    testthat::expect_identical(
      create_noul_question(criteria = list(true = value))$criteria,
      list(true = value))
  }

  testthat::expect_identical(
    create_noul_question(criteria = list(false = "Angry"))$criteria,
    list(false = "Angry"))
  testthat::expect_error(
    create_noul_question(criteria = "Calm"),
    class = "typesafer_input_error")
  testthat::expect_error(
    create_noul_question(criteria = list(true = TRUE)),
    class = "typesafer_input_error")
})

testthat::test_that("Choice and Score validate observed rubric boundaries", {
  for (count in c(1L, 255L)) {
    criteria <- setNames(rep(list(NULL), count), as.character(seq_len(count)))
    testthat::expect_identical(create_choice_question(criteria)$criteria, criteria)
  }

  for (criteria in list(NULL, list(), structure(list(), names = character()), list("one"),
                        setNames(rep(list("option"), 256L),
                                 as.character(seq_len(256L))))) {
    testthat::expect_error(create_choice_question(criteria),
                           class = "typesafer_input_error")
  }

  for (count in c(1L, 2L, 10L)) {
    levels <- rep("level", count)
    testthat::expect_identical(create_score_question(levels)$criteria, as.list(levels))
  }

  for (criteria in list(NULL, list(), character(), rep("level", 11L),
                        list(NULL), list(low = "Calm"), c(1, 2), list(TRUE))) {
    testthat::expect_error(create_score_question(criteria),
                           class = "typesafer_input_error")
  }
  testthat::expect_error(create_choice_question(), class = "typesafer_input_error")
  testthat::expect_error(create_score_question(), class = "typesafer_input_error")
})

testthat::test_that("structured instructions and descriptions are preserved", {
  # Test instructions and criteria
  instructions <- list(
    question = "Compare these",
    references = list("one"),
    metadata = NULL)
  criteria <- list(
    first = list(code = 1, active = TRUE),
    second = list("a", "b"))

  testthat::expect_identical(
    create_choice_question(criteria, instructions)$instructions,
    instructions)
  testthat::expect_identical(
    create_choice_question(criteria, instructions)$criteria,
    criteria)

  # Test levels
  levels <- list(list(low = "Calm"), list("Angry", "Severe"))

  testthat::expect_identical(
    create_score_question(levels, instructions)$criteria,
    levels)
  testthat::expect_error(
    create_choice_question(criteria, instructions = TRUE),
    class = "typesafer_input_error")
  testthat::expect_error(
    create_score_question(levels, instructions = NA_character_),
    class = "typesafer_input_error")
})

testthat::test_that("invalid names and unsupported nested R values fail safely", {
  for (criteria in list(list(a = "one", a = "two"),
                        setNames(list("one"), NA_character_), list(a = "one", "two"))) {
    testthat::expect_error(
      create_choice_question(criteria),
      class = "typesafer_input_error")
  }

  values <- list(NA_character_, NA_real_, NaN, Inf, -Inf, factor("x"), Sys.Date(),
                 data.frame(x = "x"), matrix("x"), as.raw(1L), 1 + 1i,
                 expression(x), new.env(), function() NULL)
  for (value in values) {
    testthat::expect_error(create_noul_question(list(nested = value)),
                           class = "typesafer_input_error")
    testthat::expect_error(create_score_question(list(list(nested = value))),
                           class = "typesafer_input_error")
  }

  error <- tryCatch(create_noul_question(list(private = "private content", invalid = NA)),
                    typesafer_error = identity)
  testthat::expect_false(grepl("private", conditionMessage(error)))
})
