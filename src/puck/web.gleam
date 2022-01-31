// import puck/web/logger
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/http/service.{Service}
import gleam/bit_builder.{BitBuilder}
import gleam/erlang/file
import gleam/string

fn router(request: Request(BitString)) -> Response(BitBuilder) {
  case request.path_segments(request) {
    [] -> home()
    _ -> not_found()
  }
}

fn home() {
  response.new(200)
  |> response.set_body("Hello, Joe!")
  |> response.map(bit_builder.from_string)
}

fn not_found() -> Response(BitBuilder) {
  response.new(404)
  |> response.set_body("There's nothing here...")
  |> response.map(bit_builder.from_string)
}

pub fn service() -> Service(BitString, BitBuilder) {
  router
  |> service.prepend_response_header("made-with", "Gleam")
  // |> logger.middleware
  // |> static.middleware()
}
