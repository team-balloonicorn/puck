import gleam/http/response.{Response}
import gleam/http/request.{Request}
import gleam/bit_builder.{BitBuilder}
import gleam/erlang/file
import gleam/result
import gleam/string

external fn priv_directory() -> String =
  "puck_ffi" "priv_directory"

pub fn serve_assets(
  request: Request(a),
  next: fn() -> Response(BitBuilder),
) -> Response(BitBuilder) {
  let path =
    string.concat([
      priv_directory(),
      "/static/",
      string.replace(in: request.path, each: "..", with: ""),
    ])

  let file_contents =
    path
    |> file.read_bits
    |> result.nil_error
    |> result.map(bit_builder.from_bit_string)

  case file_contents {
    Ok(bits) -> Response(200, [], bits)
    Error(_) -> next()
  }
}
