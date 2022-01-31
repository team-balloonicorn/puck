import sheets
import gleam/erlang/os
import gleam/io

pub fn main() {
  let spreadsheet_id = "1YenzpdyTtAao9lDDpMdQJMO3KDbHMjbKWi144cIVCZw"
  assert Ok(client_id) = os.get_env("CLIENT_ID")
  assert Ok(client_secret) = os.get_env("CLIENT_SECRET")
  assert Ok(refresh_token) = os.get_env("REFRESH_TOKEN")

  io.println("Getting Google API access token")

  assert Ok(access_token) =
    sheets.get_access_token(sheets.Credentials(
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: refresh_token,
    ))

  io.println("Appending payment to Google sheets")

  sheets.append_payment(access_token, spreadsheet_id)
}
