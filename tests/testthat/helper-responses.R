create_test_response <- function(status = 200L, body = NULL, headers = list()) {
  if (is.null(body))
    body <- paste0('{"models":[{"name":"jev-latest",',
                   '"description":"A model",',
                   '"release_date":"2026-09-15"}]}')
  headers <- c(list(`content-type` = "application/json"), headers)

  test_response <- httr2::response(
    status_code = status,
    headers = headers,
    body = charToRaw(body))

  return(test_response)
}

create_test_client <- function(base_url = "https://api.typesafe.ai",
                               model = "jev-latest", ...) {
  test_client <- create_typesafe_client(
    api_key = "test-key",
    base_url = base_url,
    model = model, ...)

  return(test_client)
}
