import puck/sheets
import puck/config.{Config}
import gleam/io
import gleam/erlang

const usage = "USAGE:

  puck test-payment-recording
"

pub fn main() {
  let config = config.load_from_env_or_crash()

  case erlang.start_arguments() {
    ["test-payment-recording"] -> test_payment_recording(config)
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

external fn halt(Int) -> Nil =
  "erlang" "halt"
