import gleam/list
import gleam/string
import gleam/result
import gleam/crypto
import gleam/string
import gleam/bit_string
import gleam/base
import gleam/result
import gleam/option.{Option}

pub type Attendee {
  Attendee(
    name: String,
    email: String,
    attended: Bool,
    pal: String,
    pal_attended: Bool,
    diet: String,
    accessibility: String,
    contribution: ContributionTier,
    reference: String,
  )
}

pub type ContributionTier {
  Contribute120
  Contribute95
  Contribute80
  Contribute50
  RolloverTicket
}

pub fn contribution_from_string(input: String) -> Result(ContributionTier, Nil) {
  case input {
    "120" -> Ok(Contribute120)
    "95" -> Ok(Contribute95)
    "80" -> Ok(Contribute80)
    "50" -> Ok(Contribute50)
    "rollover" -> Ok(RolloverTicket)
    _ -> Error(Nil)
  }
}

pub fn contribtion_amount(attendee: Attendee) -> Option(Int) {
  case attendee.contribution {
    RolloverTicket -> option.None
    Contribute120 -> option.Some(120)
    Contribute95 -> option.Some(95)
    Contribute80 -> option.Some(80)
    Contribute50 -> option.Some(50)
  }
}

pub fn from_query(query: List(#(String, String))) -> Result(Attendee, Nil) {
  try name = list.key_find(query, "name")
  try email = list.key_find(query, "email")
  try attended = radio_button(query, "attended")
  try pal = list.key_find(query, "pal")
  try pal_attended = radio_button(query, "pal-attended")
  try diet = list.key_find(query, "dietary-requirements")
  try accessibility = list.key_find(query, "accessibility-requirements")
  try contribution =
    list.key_find(query, "contribution")
    |> result.then(contribution_from_string)

  Ok(Attendee(
    name: name,
    email: email,
    attended: attended,
    pal: pal,
    pal_attended: pal_attended,
    diet: diet,
    accessibility: accessibility,
    contribution: contribution,
    reference: generate_reference(),
  ))
}

pub fn generate_reference() -> String {
  // Generate random string
  crypto.strong_random_bytes(50)
  |> base.url_encode64(False)
  // Remove ambiguous characters
  |> string.replace("o", "")
  |> string.replace("O", "")
  |> string.replace("0", "")
  |> string.replace("l", "")
  |> string.replace("1", "")
  |> string.replace("I", "")
  |> string.replace("i", "")
  |> string.replace("_", "")
  |> string.replace("-", "")
  // Slice it down to a desired size
  |> bit_string.from_string
  |> bit_string.slice(0, 10)
  // Convert it back to a string. This should never fail.
  |> result.then(bit_string.to_string)
  |> result.map(string.append("m-", _))
  // Try again it if fails. It never should.
  |> result.lazy_unwrap(fn() { generate_reference() })
}

fn radio_button(
  query: List(#(String, String)),
  name: String,
) -> Result(Bool, Nil) {
  try value = list.key_find(query, name)
  case value {
    "yes" -> Ok(True)
    "no" -> Ok(False)
    _ -> Error(Nil)
  }
}
