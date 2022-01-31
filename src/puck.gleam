import puck/web
import puck/sheets
import puck/config.{Config}
import gleam/io
import gleam/erlang
import gleam/http/elli

const usage = "USAGE:

  puck server
  puck test-payment-recording
"

pub fn main() {
  let config = config.load_from_env_or_crash()

  case erlang.start_arguments() {
    ["test-payment-recording"] -> test_payment_recording(config)
    ["server"] -> server(config)
    _ -> unknown()
  }
}

fn unknown() {
  io.println(usage)
  halt(1)
}

fn test_payment_recording(config: Config) {
  io.println("Appending payment to Google sheets")

  assert Ok(_) =
    sheets.Payment(
      date: "2022-01-05",
      counterparty: "Louis",
      amount: 1000,
      reference: "From Louis",
    )
    |> sheets.append_payment(config)

  io.println("Done")
}

fn server(_config: Config) {
  // Start the web server process
  assert Ok(_) = elli.start(web.service(), on_port: 3000)
  io.println("Started listening on localhost:3000 ✨")

  // Put the main process to sleep while the web server does its thing
  erlang.sleep_forever()
}

external fn halt(Int) -> Nil =
  "erlang" "halt"
