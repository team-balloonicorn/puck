import puck/config.{Config}
import puck/payment.{Payment}
import puck/attendee.{Attendee}
import gleam/io
import gleam/http
import gleam/http/request
import gleam/http/response.{Response}
import gleam/string
import gleam/bit_string
import gleam/hackney
import gleam/result
import gleam/dynamic
import gleam/option
import gleam/json as j
import gleam/otp/actor
import gleam/otp/process

pub type Error {
  HttpError(hackney.Error)
  UnexpectedJson(j.DecodeError)
  UnexpectedHttpStatus(expected: Int, response: Response(String))
}

pub fn get_access_token(config: Config) -> Result(String, Error) {
  let formdata =
    string.concat([
      "client_id=",
      config.client_id,
      "&client_secret=",
      config.client_secret,
      "&refresh_token=",
      config.refresh_token,
      "&grant_type=refresh_token",
    ])

  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_host("oauth2.googleapis.com")
    |> request.set_path("/token")
    |> request.prepend_header(
      "content-type",
      "application/x-www-form-urlencoded",
    )
    |> request.set_body(formdata)

  try response =
    hackney.send(request)
    |> result.map_error(HttpError)
    |> result.then(ensure_status(_, is: 200))

  try json =
    response.body
    |> j.decode(using: dynamic.field("access_token", of: dynamic.string))
    |> result.map_error(UnexpectedJson)

  Ok(json)
}

fn ensure_status(
  response: Response(String),
  is code: Int,
) -> Result(Response(String), Error) {
  case response.status == code {
    True -> Ok(response)
    False -> Error(UnexpectedHttpStatus(expected: code, response: response))
  }
}

pub fn append_attendee(attendee: Attendee, config: Config) -> Result(Nil, Error) {
  try access_token = get_access_token(config)

  let json =
    j.to_string(j.object([
      #("range", j.string("attendees!A:A")),
      #("majorDimension", j.string("ROWS")),
      #(
        "values",
        j.preprocessed_array([
          j.preprocessed_array([
            j.string(attendee.reference),
            j.string(timestamp()),
            j.string(attendee.name),
            j.string(attendee.email),
            j.string(attendee.pal),
            j.bool(attendee.attended),
            j.bool(attendee.pal_attended),
            j.string(case attendee.contribution {
              attendee.RolloverTicket -> "Rollover ticket"
              attendee.Contribute120 -> "120"
              attendee.Contribute95 -> "95"
              attendee.Contribute80 -> "80"
              attendee.Contribute50 -> "50"
            }),
            j.string(attendee.diet),
            j.string(attendee.accessibility),
          ]),
        ]),
      ),
    ]))

  let path =
    string.concat([
      "/v4/spreadsheets/",
      config.spreadsheet_id,
      "/values/attendees!A:A:append?valueInputOption=USER_ENTERED&access_token=",
      access_token,
    ])

  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_body(json)
    |> request.set_host("sheets.googleapis.com")
    |> request.set_path(path)
    |> request.prepend_header("content-type", "application/json")

  try _ =
    hackney.send(request)
    |> result.map_error(HttpError)
    |> result.then(ensure_status(_, is: 200))

  Ok(Nil)
}

pub fn append_payment(payment: Payment, config: Config) -> Result(Nil, Error) {
  try access_token = get_access_token(config)

  let json =
    j.to_string(j.object([
      #("range", j.string("payments!A:E")),
      #("majorDimension", j.string("ROWS")),
      #(
        "values",
        j.preprocessed_array([
          j.preprocessed_array([
            j.string(payment.created_at),
            j.string(payment.counterparty),
            j.int(payment.amount),
            j.string(payment.reference),
          ]),
        ]),
      ),
    ]))

  let path =
    string.concat([
      "/v4/spreadsheets/",
      config.spreadsheet_id,
      "/values/payments!A:E:append?valueInputOption=USER_ENTERED&access_token=",
      access_token,
    ])

  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_body(json)
    |> request.set_host("sheets.googleapis.com")
    |> request.set_path(path)
    |> request.prepend_header("content-type", "application/json")

  try _ =
    hackney.send(request)
    |> result.map_error(HttpError)
    |> result.then(ensure_status(_, is: 200))

  Ok(Nil)
}

type RefresherState {
  RefresherState(config: Config, sender: process.Sender(Nil))
}

pub fn start_refresher(config: Config) -> Result(Nil, Nil) {
  actor.start_spec(actor.Spec(
    init: fn() { refresher_init(config) },
    init_timeout: 500,
    loop: refresher_loop,
  ))
  |> result.nil_error
  |> result.map(fn(_) { Nil })
}

fn refresher_init(config: Config) -> actor.InitResult(RefresherState, Nil) {
  let #(sender, receiver) = process.new_channel()
  let state = RefresherState(sender: sender, config: config)
  process.send_after(state.sender, 1000, Nil)
  actor.Ready(state, option.Some(receiver))
}

fn refresher_loop(
  _message: Nil,
  state: RefresherState,
) -> actor.Next(RefresherState) {
  io.println("Periodically refreshing Google Sheets OAuth token")
  let sleep_period = case get_access_token(state.config) {
    Ok(_) -> {
      io.println("Token refreshed successfully")
      1000 * 60 * 60 * 3
    }
    Error(error) -> {
      io.println("Token refresh failed")
      io.debug(error)
      1000 * 60 * 10
    }
  }
  process.send_after(state.sender, sleep_period, Nil)
  actor.Continue(state)
}

external fn timestamp() -> String =
  "puck_ffi" "timestamp"
