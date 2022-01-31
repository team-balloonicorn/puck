import puck/sheets
import puck/config
import gleam/io

pub fn main() {
  let config = config.load_from_env_or_crash()

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
