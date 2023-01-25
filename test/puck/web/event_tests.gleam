import gleam/http
import gleam/http/response
import gleam/http/request
import gleam/erlang/process
import gleam/uri
import gleam/int
import gleam/option.{Some}
import gleam/string
import puck/user
import puck/web/routes
import puck/web/auth
import tests

pub fn attendance_form_not_logged_in_test() {
  use state <- tests.with_state
  let secret = state.config.attend_secret
  let response =
    tests.request("/" <> secret)
    |> routes.router(state)
  assert 200 = response.status
  assert True = string.contains(response.body, "Midsummer Night's Tea Party")
  assert False = string.contains(response.body, "Continue to your account")
  assert True = string.contains(response.body, "What's your email?")
  assert True = string.contains(response.body, "action=\"/sign-up/" <> secret)
}

pub fn attendance_form_logged_in_test() {
  use state <- tests.with_logged_in_state
  let secret = state.config.attend_secret
  let response =
    tests.request("/" <> secret)
    |> routes.router(state)
  assert 200 = response.status
  assert True = string.contains(response.body, "Midsummer Night's Tea Party")
  assert True = string.contains(response.body, "Continue to your account")
  assert False = string.contains(response.body, "What's your email?")
  assert False = string.contains(response.body, "href=\"/sign-up/" <> secret)
}
