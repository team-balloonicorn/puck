import puck/payment
import puck/sheets
import puck/config.{Config}
import puck/web/logger
import puck/web/static
import puck/web/templates.{Templates}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/http/service.{Service}
import gleam/bit_builder.{BitBuilder}
import gleam/erlang/file
import gleam/bit_string
import gleam/result
import gleam/string
import gleam/json
import gleam/io

pub type State {
  State(templates: Templates, config: Config)
}

pub fn service(config: Config) -> Service(BitString, BitBuilder) {
  let state = State(config: config, templates: templates.load())

  router(_, state)
  |> service.prepend_response_header("made-with", "Gleam")
  |> service.map_response_body(bit_builder.from_string)
  |> logger.middleware
  |> static.middleware()
}

fn router(request: Request(BitString), state: State) -> Response(String) {
  case request.path_segments(request) {
    ["2022"] -> home(state)
    ["api", "payment", key] -> payments(request, key, state.config)
    _ -> not_found()
  }
}

fn home(state: State) {
  let html = state.templates.home()
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
}

fn not_found() {
  response.new(404)
  |> response.set_body("There's nothing here...")
}

type WebError {
  UnexpectedJson(json.DecodeError)
  SaveFailed(sheets.Error)
}

// TODO: verify key
// TODO: tests
fn payments(request: Request(BitString), _key: String, config: Config) {
  payment.from_json(request.body)
  |> result.map_error(UnexpectedJson)
  |> result.then(fn(payment) {
    try _ =
      payment
      |> sheets.append_payment(config)
      |> result.map_error(SaveFailed)
    Ok(response.new(200))
  })
  |> result.map_error(io.debug)
  |> result.map_error(error_to_response(_, request))
  |> unwrap_both
}

fn unwrap_both(result: Result(a, a)) -> a {
  case result {
    Ok(value) -> value
    Error(value) -> value
  }
}

fn error_to_response(
  error: WebError,
  request: Request(BitString),
) -> Response(String) {
  case error {
    UnexpectedJson(_) -> {
      request.body
      |> bit_string.to_string
      |> result.unwrap("")
      |> string.append("ERROR: Unexpected JSON: ", _)
      |> io.println
      response.new(400)
    }

    SaveFailed(_) -> response.new(500)
  }
}
