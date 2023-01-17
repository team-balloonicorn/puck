import puck/web/templates.{Templates}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/http/service.{Service}
import gleam/bit_builder.{BitBuilder}
import gleam/bit_string
import gleam/uri

pub fn not_found() {
  response.new(404)
  |> response.set_body("There's nothing here...")
}

pub fn method_not_allowed() -> Response(String) {
  response.new(405)
  |> response.set_body("Method not allowed")
}

pub fn unprocessable_entity() -> Response(String) {
  response.new(422)
  |> response.set_body(
    "Unprocessable entity. Please try again and contact the organisers if the problem continues",
  )
}

pub fn bad_request() -> Response(String) {
  response.new(400)
  |> response.set_body(
    "Invalid request. Please try again and contact the organisers if the problem continues",
  )
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

pub fn require_ok(
  result: Result(a, b),
  next: fn(a) -> Response(String),
) -> Response(String) {
  case result {
    Ok(value) -> next(value)
    Error(_) -> unprocessable_entity()
  }
}
