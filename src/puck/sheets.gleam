import puck/config.{Config}
import puck/payment.{Payment}
import puck/attendee.{Attendee}
import gleam/io
import gleam/list
import gleam/http
import gleam/http/request
import gleam/http/response.{Response}
import gleam/int
import gleam/map.{Map}
import gleam/set.{Set}
import gleam/string
import gleam/hackney
import gleam/result
import gleam/dynamic
import gleam/option.{Option}
import gleam/json.{Json} as j
import gleam/otp/actor
import gleam/erlang/process

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

fn append_row(
  sheet: String,
  row: List(Json),
  config: Config,
) -> Result(Nil, Error) {
  try access_token = get_access_token(config)

  let json =
    j.to_string(j.object([
      #("range", j.string(string.append(sheet, "!A:A"))),
      #("majorDimension", j.string("ROWS")),
      #("values", j.preprocessed_array([j.preprocessed_array(row)])),
    ]))

  let path =
    string.concat([
      "/v4/spreadsheets/",
      config.spreadsheet_id,
      "/values/",
      sheet,
      "!A:A:append?valueInputOption=USER_ENTERED&access_token=",
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

pub fn all_references(
  access_token: String,
  config: Config,
) -> Result(Map(String, Int), Error) {
  try references = get_column("attendees", "A", access_token, config)

  references
  |> list.map(string.lowercase)
  |> list.index_map(fn(i, ref) { #(ref, i + 1) })
  |> map.from_list
  |> Ok
}

pub fn all_attendee_emails(
  access_token: String,
  config: Config,
) -> Result(Set(String), Error) {
  try emails = get_column("attendees", "D", access_token, config)

  emails
  |> list.map(string.lowercase)
  |> set.from_list
  |> Ok
}

fn get_column(
  sheet: String,
  column: String,
  access_token: String,
  config: Config,
) -> Result(List(String), Error) {
  let path =
    string.concat([
      "/v4/spreadsheets/",
      config.spreadsheet_id,
      "/values/",
      sheet,
      "!",
      column,
      "1:",
      column,
      "1002?majorDimension=COLUMNS&access_token=",
      access_token,
    ])

  let request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_host("sheets.googleapis.com")
    |> request.set_path(path)

  try response =
    hackney.send(request)
    |> result.map_error(HttpError)
    |> result.then(ensure_status(_, is: 200))

  try references =
    response.body
    |> j.decode(using: dynamic.field(
      "values",
      of: dynamic.list(of: dynamic.list(of: dynamic.string)),
    ))
    |> result.map_error(UnexpectedJson)

  references
  |> list.flatten
  |> Ok
}

pub fn get_row(
  sheet: String,
  row_number: Int,
  row_decoder: dynamic.Decoder(t),
  access_token: String,
  config: Config,
) -> Result(Option(t), Error) {
  let row_number = int.to_string(row_number)
  let path =
    string.concat([
      "/v4/spreadsheets/",
      config.spreadsheet_id,
      "/values/",
      sheet,
      "!A",
      row_number,
      ":Z",
      row_number,
      "?majorDimension=ROWS&access_token=",
      access_token,
    ])

  let request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_host("sheets.googleapis.com")
    |> request.set_path(path)

  try response =
    hackney.send(request)
    |> result.map_error(HttpError)
    |> result.then(ensure_status(_, is: 200))

  try rows =
    response.body
    |> j.decode(using: dynamic.field(
      "values",
      of: dynamic.list(of: row_decoder),
    ))
    |> result.map_error(UnexpectedJson)

  case rows {
    [row] -> Ok(option.Some(row))
    _ -> Ok(option.None)
  }
}

pub fn get_attendee_email(
  reference: String,
  config: Config,
) -> Result(Option(String), Error) {
  let reference = string.lowercase(reference)
  try access_token = get_access_token(config)
  try references = all_references(access_token, config)

  let decoder = fn(dyn) {
    try list = dynamic.shallow_list(dyn)
    case list {
      [_ref, _timestamp, _name, email, ..] -> dynamic.string(email)
      _ -> {
        let error =
          dynamic.DecodeError(expected: "String", found: "nothing", path: ["3"])
        Error([error])
      }
    }
  }

  case map.get(references, reference) {
    Error(Nil) -> Ok(option.None)
    Ok(row_number) ->
      get_row("attendees", row_number, decoder, access_token, config)
  }
}

pub fn append_attendee(attendee: Attendee, config: Config) -> Result(Nil, Error) {
  // Sum the total payments for this attendee's reference
  let total_paid_formula =
    "=sumif(payments!D:D,indirect(\"A\"&row()),payments!C:C)/100"

  let row = [
    j.string(attendee.reference),
    j.string(timestamp()),
    j.string(attendee.name),
    j.string(attendee.email),
    j.string(attendee.pal),
    j.bool(attendee.attended),
    j.bool(attendee.pal_attended),
    j.string(attendee.diet),
    j.string(attendee.accessibility),
    j.string(total_paid_formula),
  ]
  append_row("attendees", row, config)
}

pub fn append_payment(payment: Payment, config: Config) -> Result(Nil, Error) {
  let row = [
    j.string(payment.created_at),
    j.string(payment.counterparty),
    j.int(payment.amount),
    j.string(payment.reference),
  ]

  append_row("payments", row, config)
}

type RefresherState {
  RefresherState(config: Config, subject: process.Subject(Nil))
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
  let subject = process.new_subject()
  let state = RefresherState(subject: subject, config: config)
  let selector =
    process.new_selector()
    |> process.selecting(subject, fn(x) { x })
  process.send_after(state.subject, 1000, Nil)
  actor.Ready(state, selector)
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
  process.send_after(state.subject, sleep_period, Nil)
  actor.Continue(state)
}

external fn timestamp() -> String =
  "puck_ffi" "timestamp"
