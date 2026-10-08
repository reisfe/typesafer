create_test_response <- function(status = 200L,
                                 body = '{"models":[{"name":"jev-latest","description":"A model","release_date":"2026-09-15"}]}',
                                 headers = list()) {
    headers <- c(list(`content-type` = "application/json"), headers)
    return(httr2::response(status_code = status, headers = headers,
                           body = charToRaw(body)))
}

create_test_client <- function(base_url = "https://api.typesafe.ai",
                               model = "jev-latest", ...) {
    return(create_typesafe_client(api_key = "test-key", base_url = base_url,
                                  model = model, ...))
}
