import gleam/http/response
import puck/routes
import wisp/testing
import tests

pub fn unknown_page_test() {
  use ctx <- tests.with_context
  let response =
    testing.get("/wibble", [])
    |> routes.handle_request(ctx)
  let assert 404 = response.status
}

pub fn licence_page_test() {
  use ctx <- tests.with_context
  let response =
    testing.get("/licence", [])
    |> routes.handle_request(ctx)
  let assert 200 = response.status
}

pub fn home_not_logged_in_test() {
  use ctx <- tests.with_context
  let response =
    testing.get("/", [])
    |> routes.handle_request(ctx)
  let assert 303 = response.status
  let assert Ok("/login") = response.get_header(response, "location")
}

pub fn home_logged_in_test() {
  use ctx <- tests.with_logged_in_context
  let response =
    testing.get("/", [])
    |> routes.handle_request(ctx)
  let assert 200 = response.status
  let assert Error(Nil) = response.get_header(response, "location")
}

pub fn costs_not_logged_in_test() {
  use ctx <- tests.with_context
  let response =
    testing.get("/costs", [])
    |> routes.handle_request(ctx)
  let assert 303 = response.status
  let assert Ok("/login") = response.get_header(response, "location")
}

pub fn costs_logged_in_test() {
  use ctx <- tests.with_logged_in_context
  let response =
    testing.get("/costs", [])
    |> routes.handle_request(ctx)
  let assert 200 = response.status
  let assert Error(Nil) = response.get_header(response, "location")
}
