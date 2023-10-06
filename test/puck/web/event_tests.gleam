import gleam/http/response
import gleam/map
import gleam/option.{Some}
import gleam/string
import gleam/list
import puck/user
import puck/routes
import wisp/testing
import tests

pub fn attendance_form_not_logged_in_test() {
  use ctx <- tests.with_context
  let secret = ctx.config.attend_secret
  let response =
    testing.get("/" <> secret, [])
    |> routes.handle_request(ctx)
  let assert 200 = response.status
  let assert True =
    response
    |> testing.string_body
    |> string.contains("Midsummer Night's Tea Party")
  let assert False =
    response
    |> testing.string_body
    |> string.contains("Continue to your account")
  let assert True =
    response
    |> testing.string_body
    |> string.contains("What's your email?")
  let assert True =
    response
    |> testing.string_body
    |> string.contains("action=\"/sign-up/" <> secret)
}

pub fn attendance_form_logged_in_test() {
  use ctx <- tests.with_logged_in_context
  let secret = ctx.config.attend_secret
  let response =
    testing.get("/" <> secret, [])
    |> routes.handle_request(ctx)
  let assert 200 = response.status
  let assert True =
    response
    |> testing.string_body
    |> string.contains("Midsummer Night's Tea Party")
  let assert True =
    response
    |> testing.string_body
    |> string.contains("Continue to your account")
  let assert False =
    response
    |> testing.string_body
    |> string.contains("What's your email?")
  let assert False =
    response
    |> testing.string_body
    |> string.contains("href=\"/sign-up/" <> secret)
}

pub fn register_attendance_ok_test() {
  use ctx <- tests.with_logged_in_context
  let assert Some(user) = ctx.current_user
  let secret = ctx.config.attend_secret
  let form = [
    #("attended", "Yes"),
    #("support-network", "Lauren, Bell"),
    #("support-network-attended", "Lauren"),
    #("dietary-requirements", "Vegan"),
    #("accessibility-requirements", "I walk with a stick"),
    #("other", "This should not be recorded"),
  ]
  let response =
    testing.post_form("/" <> secret, [], form)
    |> routes.handle_request(ctx)
  let assert 303 = response.status
  let assert Ok("/") = response.get_header(response, "location")
  let assert Ok(Some(application)) = user.get_application(ctx.db, user.id)
  let assert "m-" <> _ = application.payment_reference
  let assert True = application.user_id == user.id
  let assert [
    #("accessibility-requirements", "I walk with a stick"),
    #("attended", "Yes"),
    #("dietary-requirements", "Vegan"),
    #("support-network", "Lauren, Bell"),
    #("support-network-attended", "Lauren"),
  ] =
    application.answers
    |> map.to_list
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
}

pub fn register_attendance_not_logged_in_test() {
  use ctx <- tests.with_context
  let secret = ctx.config.attend_secret
  let response =
    testing.post("/" <> secret, [], "")
    |> routes.handle_request(ctx)
  let assert 303 = response.status
  let assert Ok("/login") = response.get_header(response, "location")
}
