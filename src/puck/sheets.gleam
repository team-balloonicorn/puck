import puck/config.{Config}
import gleam/io
import gleam/http
import gleam/http/request
import gleam/http/response.{Response}
import gleam/string
import gleam/bit_string
import gleam/hackney
import gleam/result
import gleam/dynamic
import gleam/json as j

pub type Payment {
  Payment(date: String, counterparty: String, amount: Int, reference: String)
}

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
            j.string(payment.date),
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
