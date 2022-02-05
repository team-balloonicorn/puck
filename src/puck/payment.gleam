import gleam/io
import gleam/json
import gleam/dynamic.{field, int, string}

pub type Payment {
  Payment(
    created_at: String,
    counterparty: String,
    amount: Int,
    reference: String,
  )
}

pub fn from_json(json: BitString) -> Result(Payment, json.DecodeError) {
  let decoder =
    dynamic.decode4(
      Payment,
      field("data", field("created", string)),
      field(
        "data",
        dynamic.any([
          field("counterparty", field("name", string)),
          field("merchant", field("name", string)),
        ]),
      ),
      field("data", field("amount", int)),
      field(
        "data",
        dynamic.any([field("notes", string), field("description", string)]),
      ),
    )

  json.decode_bits(from: json, using: decoder)
}
