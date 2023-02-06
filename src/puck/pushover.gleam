import gleam/json
import gleam/string
import gleam/result
import gleam/hackney
import gleam/http.{Post}
import gleam/http/request
import puck/config.{Config}
import puck/error.{Error}

pub fn notify(
  config: Config,
  title title: String,
  message message: String,
) -> Result(Nil, Error) {
  let json =
    json.to_string(json.object([
      #("token", json.string(config.pushover_key)),
      #("user", json.string(config.pushover_user)),
      #("title", json.string(string.slice(title, 0, length: 1024))),
      #("message", json.string(string.slice(message, 0, length: 250))),
    ]))

  let request =
    request.new()
    |> request.set_method(Post)
    |> request.set_host("api.pushover.net")
    |> request.set_path("/1/messages.json")
    |> request.set_body(json)
    |> request.prepend_header("accept", "application/json")
    |> request.prepend_header("content-type", "application/json")

  use response <- result.then(
    hackney.send(request)
    |> result.map_error(error.Hackney),
  )

  case response.status {
    200 -> Ok(Nil)
    code -> Error(error.UnexpectedPushoverResponse(code, response.body))
  }
}
