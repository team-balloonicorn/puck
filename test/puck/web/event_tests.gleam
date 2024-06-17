import gleam/http/response
import gleam/option.{Some}
import gleam/string
import puck/routes
import puck/user
import tests
import wisp/testing

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
  ]
  let response =
    testing.post_form("/" <> secret, [], form)
    |> routes.handle_request(ctx)
  let assert 303 = response.status
  let assert Ok("/") = response.get_header(response, "location")
  let assert Ok(Some(user)) = user.get_by_email(ctx.db, user.email)
  let assert Some(True) = user.attended_before
  let assert "I walk with a stick" = user.accessibility_requirements
  let assert "Vegan" = user.dietary_requirements
  let assert "Lauren, Bell" = user.support_network
  let assert "Lauren" = user.support_network_attended
}

pub fn register_attendance_invalid_field_test() {
  use ctx <- tests.with_logged_in_context
  let assert Some(user) = ctx.current_user
  let secret = ctx.config.attend_secret
  let form = [#("is-admin", "Yes")]
  let response =
    testing.post_form("/" <> secret, [], form)
    |> routes.handle_request(ctx)
  let assert 200 = response.status
  let assert Ok(Some(user)) = user.get_by_email(ctx.db, user.email)
  let assert False = user.is_admin
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
