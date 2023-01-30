import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/map
import gleam/option.{Some}
import gleam/string
import gleam/list
import gleam/uri
import puck/user
import puck/web/routes
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

pub fn register_attendance_ok_test() {
  use state <- tests.with_logged_in_state
  assert Some(user) = state.current_user
  let secret = state.config.attend_secret
  let body =
    uri.query_to_string([
      #("attended", "yes"),
      #("pod-members", "Lauren, Bell"),
      #("pod-attended", "Lauren"),
      #("dietary-requirements", "Vegan"),
      #("accessibility-requirements", "I walk with a stick"),
      #("other", "This should not be recorded"),
    ])
  let response =
    tests.request("/" <> secret)
    |> request.set_method(http.Post)
    |> request.set_body(<<body:utf8>>)
    |> routes.router(state)
  assert 302 = response.status
  assert Ok("/") = response.get_header(response, "location")
  assert Ok(Some(application)) = user.get_application(state.db, user.id)
  assert "m-" <> _ = application.payment_reference
  assert True = application.user_id == user.id
  assert [
    #("accessibility-requirements", "I walk with a stick"),
    #("attended", "yes"),
    #("dietary-requirements", "Vegan"),
    #("pod-attended", "Lauren"),
    #("pod-members", "Lauren, Bell"),
  ] =
    application.answers
    |> map.to_list
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
}

pub fn register_attendance_not_logged_in_test() {
  use state <- tests.with_state
  let secret = state.config.attend_secret
  let response =
    tests.request("/" <> secret)
    |> request.set_method(http.Post)
    |> routes.router(state)
  assert 302 = response.status
  assert Ok("/login") = response.get_header(response, "location")
}
