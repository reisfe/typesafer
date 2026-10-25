testthat::test_that("evaluation response helper uses the fixture by default", {
  response <- create_evaluation_response()

  testthat::expect_identical(httr2::resp_status(response), 200L)
  testthat::expect_identical(httr2::resp_body_string(response), read_evaluation_fixture())
})

testthat::test_that("evaluation response helper serializes custom results as the body", {
  result <- list(model = "resolved", score = 0.799999999, future = NULL)
  response <- create_evaluation_response(result)

  testthat::expect_identical(httr2::resp_status(response), 200L)
  testthat::expect_identical(
    httr2::resp_body_json(response, simplifyVector = FALSE), result)
})
