import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/map
import gleam/option.{Some}
import gleam/string
import gleam/string_builder
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
  let assert 200 = response.status
  let assert True =
    response.body
    |> string_builder.to_string
    |> string.contains("Midsummer Night's Tea Party")
  let assert False =
    response.body
    |> string_builder.to_string
    |> string.contains("Continue to your account")
  let assert True =
    response.body
    |> string_builder.to_string
    |> string.contains("What's your email?")
  let assert True =
    response.body
    |> string_builder.to_string
    |> string.contains("action=\"/sign-up/" <> secret)
}

pub fn attendance_form_logged_in_test() {
  use state <- tests.with_logged_in_state
  let secret = state.config.attend_secret
  let response =
    tests.request("/" <> secret)
    |> routes.router(state)
  let assert 200 = response.status
  let assert True =
    response.body
    |> string_builder.to_string
    |> string.contains("Midsummer Night's Tea Party")
  let assert True =
    response.body
    |> string_builder.to_string
    |> string.contains("Continue to your account")
  let assert False =
    response.body
    |> string_builder.to_string
    |> string.contains("What's your email?")
  let assert False =
    response.body
    |> string_builder.to_string
    |> string.contains("href=\"/sign-up/" <> secret)
}

pub fn register_attendance_ok_test() {
  use state <- tests.with_logged_in_state
  let assert Some(user) = state.current_user
  let secret = state.config.attend_secret
  let body =
    uri.query_to_string([
      #("attended", "Yes"),
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
  let assert 302 = response.status
  let assert Ok("/") = response.get_header(response, "location")
  let assert Ok(Some(application)) = user.get_application(state.db, user.id)
  let assert "m-" <> _ = application.payment_reference
  let assert True = application.user_id == user.id
  let assert [
    #("accessibility-requirements", "I walk with a stick"),
    #("attended", "Yes"),
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
  let assert 302 = response.status
  let assert Ok("/login") = response.get_header(response, "location")
}
