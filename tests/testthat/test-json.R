testthat::test_that("request serialization preserves singleton arrays, objects and nulls", {
    body <- list(scalar = "one", array = list("one"), empty_array = list(),
                 empty_object = structure(list(), names = character()), explicit_null = NULL,
                 nested = list(list("one")), vector = c("one", "two"),
                 numbers = c(1.23456789012345, 2), logicals = c(TRUE, FALSE))
    json <- serialize_json_body(body)
    testthat::expect_match(json, '"scalar":"one"', fixed = TRUE)
    testthat::expect_match(json, '"array":["one"]', fixed = TRUE)
    testthat::expect_match(json, '"empty_array":[]', fixed = TRUE)
    testthat::expect_match(json, '"empty_object":{}', fixed = TRUE)
    testthat::expect_match(json, '"explicit_null":null', fixed = TRUE)
    testthat::expect_match(json, '"nested":[["one"]]', fixed = TRUE)
    testthat::expect_match(json, '"vector":["one","two"]', fixed = TRUE)
    decoded <- jsonlite::fromJSON(json, simplifyVector = FALSE)
    testthat::expect_identical(decoded$numbers[[1L]], body$numbers[[1L]])
    testthat::expect_identical(decoded$logicals, list(TRUE, FALSE))
})

testthat::test_that("UTF-8, quotes, backslashes and newlines survive JSON encoding", {
    value <- enc2utf8('Caf\u00e9 "quoted" \\ path\nnext line')
    body <- setNames(list(value), enc2utf8("\u00e9quipe technique"))
    decoded <- jsonlite::fromJSON(serialize_json_body(body), simplifyVector = FALSE)
    testthat::expect_identical(decoded, body)
})

testthat::test_that("array vectors are explicit and empty objects retain names", {
    testthat::expect_identical(normalize_json_value(c(a = "one", b = "two")), list("one", "two"))
    testthat::expect_identical(normalize_json_value(character()), list())
    testthat::expect_identical(normalize_json_value(list("one")), list("one"))
    object <- structure(list(), names = character())
    testthat::expect_identical(normalize_json_value(object), object)
})
