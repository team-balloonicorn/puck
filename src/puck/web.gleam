import gleam/bit_string
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/option.{None, Option, Some}
import gleam/uri
import puck/config.{Config}
import puck/database
import puck/user.{User}
import puck/web/templates.{Templates}

const login_path = "/login"

const please_try_again = " Please try again and contact the organisers if the problem continues."

pub type State {
  State(
    templates: Templates,
    db: database.Connection,
    config: Config,
    current_user: Option(User),
  )
}

pub fn redirect(target: String) -> Response(String) {
  response.new(302)
  |> response.set_header("Location", target)
  |> response.set_body("You are being redirected")
}

pub fn not_found() -> Response(String) {
  response.new(404)
  |> response.set_body("There's nothing here.")
}

pub fn method_not_allowed() -> Response(String) {
  response.new(405)
  |> response.set_body("Method not allowed")
}

pub fn unprocessable_entity() -> Response(String) {
  response.new(422)
  |> response.set_body("Unprocessable entity." <> please_try_again)
}

pub fn bad_request() -> Response(String) {
  response.new(400)
  |> response.set_body("Invalid request." <> please_try_again)
}

pub fn require_user(
  state: State,
  next: fn(User) -> Response(String),
) -> Response(String) {
  case state.current_user {
    Some(user) -> next(user)
    None -> redirect(login_path)
  }
}

pub fn require_bit_string_body(
  request: Request(BitString),
  next: fn(String) -> Response(String),
) -> Response(String) {
  case bit_string.to_string(request.body) {
    Ok(body) -> next(body)
    Error(_) -> bad_request()
  }
}

pub fn require_form_urlencoded_body(
  request: Request(BitString),
  next: fn(List(#(String, String))) -> Response(String),
) -> Response(String) {
  use body <- require_bit_string_body(request)
  case uri.parse_query(body) {
    Ok(body) -> next(body)
    Error(_) -> unprocessable_entity()
  }
}

pub fn ok(
  result: Result(a, b),
  next: fn(a) -> Response(String),
) -> Response(String) {
  case result {
    Ok(value) -> next(value)
    Error(_) -> unprocessable_entity()
  }
}

pub fn ok_or_404(
  result: Result(a, b),
  next: fn(a) -> Response(String),
) -> Response(String) {
  case result {
    Ok(value) -> next(value)
    Error(_) -> not_found()
  }
}

pub fn some(
  result: Option(a),
  next: fn(a) -> Response(String),
) -> Response(String) {
  case result {
    Some(value) -> next(value)
    None -> not_found()
  }
}

pub fn true_or_404(
  result: Bool,
  next: fn() -> Response(String),
) -> Response(String) {
  case result {
    True -> next()
    False -> not_found()
  }
}
