import gleam/io
import gleam/int
import gleam/http
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
  UnexpectedHttpStatus(expected: Int, response: http.Response(String))
}

pub type Credentials {
  Credentials(client_id: String, client_secret: String, refresh_token: String)
}

pub fn get_access_token(credentials: Credentials) -> Result(String, Error) {
  let formdata =
    string.concat([
      "client_id=",
      credentials.client_id,
      "&client_secret=",
      credentials.client_secret,
      "&refresh_token=",
      credentials.refresh_token,
      "&grant_type=refresh_token",
    ])

  let request =
    http.default_req()
    |> http.set_method(http.Post)
    |> http.set_host("oauth2.googleapis.com")
    |> http.set_path("/token")
    |> http.prepend_req_header(
      "content-type",
      "application/x-www-form-urlencoded",
    )
    |> http.set_req_body(formdata)

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
  response: http.Response(String),
  is code: Int,
) -> Result(http.Response(String), Error) {
  case response.status == code {
    True -> Ok(response)
    False -> Error(UnexpectedHttpStatus(expected: code, response: response))
  }
}

// https://developers.google.com/sheets/api/samples/writing#append_values
//
// PUT https://sheets.googleapis.com/v4/spreadsheets/spreadsheetId/values/Sheet1!A1:D5?valueInputOption=USER_ENTERED
//
// ```json
// {
//   "range": "Sheet1!A1:E1",
//   "majorDimension": "ROWS",
//   "values": [
//     ["Door", "$15", "2", "3/15/2016"],
//     ["Engine", "$100", "1", "3/20/2016"],
//   ],
// }
// ```
//
pub fn append_payment(
  access_token: String,
  spreadsheet_id: String,
  payment: Payment,
) -> Result(Nil, Error) {
  let json =
    j.to_string(j.object([
      #("range", j.string("payments!A:E")),
      #("majorDimension", j.string("ROWS")),
      #(
        "values",
        j.array(
          of: j.array(_, j.string),
          from: [
            [
              payment.date,
              payment.counterparty,
              int.to_string(payment.amount),
              payment.reference,
            ],
          ],
        ),
      ),
    ]))

  let path =
    string.concat([
      "/v4/spreadsheets/",
      spreadsheet_id,
      "/values/payments!A:E:append?valueInputOption=USER_ENTERED&access_token=",
      access_token,
    ])

  let request =
    http.default_req()
    |> http.set_method(http.Post)
    |> http.set_req_body(json)
    |> http.set_host("sheets.googleapis.com")
    |> http.set_path(path)
    |> http.prepend_req_header("content-type", "application/json")

  assert Ok(response) = hackney.send(request)

  // TODO: check status
  // TODO: return errors
  io.println(response.body)

  Ok(Nil)
}
