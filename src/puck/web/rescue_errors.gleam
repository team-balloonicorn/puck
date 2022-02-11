import gleam/http/response
import gleam/http/service.{Service}
import gleam/bit_builder.{BitBuilder}
import gleam/erlang
import gleam/io

pub fn middleware(service: Service(a, BitBuilder)) -> Service(a, BitBuilder) {
  fn(request) {
    case erlang.rescue(fn() { service(request) }) {
      Ok(response) -> response

      Error(error) -> {
        error
        |> anything_to_string
        |> log_error
        response.new(500)
        |> response.prepend_header("content-type", "text/html")
        |> response.set_body(bit_builder.from_string(
          "<h1>Internal server error</h1><p>Sorry! Please try again in an hour or so to give us time to fix this.</p>",
        ))
      }
    }
  }
}

external fn log_error(string) -> Nil =
  "logger" "error"

external fn anything_to_string(anything) -> String =
  "puck_log_handler" "anything_to_string"
