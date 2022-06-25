import gleam/io
import gleam/int
import gleam/list
import gleam/string
import gleam/result
import gleam/crypto
import gleam/string
import gleam/bit_string
import gleam/base
import gleam/result
import puck/config.{Config}
import puck/email

pub type Attendee {
  Attendee(
    name: String,
    email: String,
    attended: Bool,
    pal: String,
    pal_attended: Bool,
    diet: String,
    accessibility: String,
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

pub fn from_query(query: List(#(String, String))) -> Result(Attendee, Nil) {
  try name = list.key_find(query, "name")
  try email = list.key_find(query, "email")
  try attended = radio_button(query, "attended")
  try pal = list.key_find(query, "pal")
  try pal_attended = radio_button(query, "pal-attended")
  try diet = list.key_find(query, "dietary-requirements")
  try accessibility = list.key_find(query, "accessibility-requirements")

  Ok(Attendee(
    name: escape(name),
    email: escape(email),
    attended: attended,
    pal: escape(pal),
    pal_attended: pal_attended,
    diet: escape(diet),
    accessibility: escape(accessibility),
    reference: generate_reference(),
  ))
}

pub fn generate_reference() -> String {
  // Generate random string
  crypto.strong_random_bytes(50)
  |> base.url_encode64(False)
  |> string.lowercase
  // Remove ambiguous characters
  |> string.replace("o", "")
  |> string.replace("O", "")
  |> string.replace("0", "")
  |> string.replace("1", "")
  |> string.replace("i", "")
  |> string.replace("l", "")
  |> string.replace("_", "")
  |> string.replace("-", "")
  // Slice it down to a desired size
  |> bit_string.from_string
  |> bit_string.slice(0, 12)
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

fn escape(input: String) -> String {
  case string.starts_with(input, "=") {
    True -> string.append(" ", input)
    False -> input
  }
}

pub fn payment_confirmation_email(pence: Int) -> String {
  string.concat([
    "Hello!

We received your payment of £",
    int.to_string(pence / 100),
    ".",
    string.pad_left(int.to_string(pence % 100), to: 2, with: "0"),
    ".

Thanks,
The Midsummer crew",
  ])
}

pub fn attendance_email(reference: String, config: Config) -> String {
  string.concat([
    "Hello!

Here are the bank details for your ticket contribution:

- Name: ",
    config.account_name,
    "
- Account no: ",
    config.account_number,
    "
- Sort code: ",
    config.sort_code,
    "
- Reference: ",
    reference,
    "

We don't make a profit from these events, so please contribute what you can. To cover site fees we need one of:
- 70 people paying £50
- 50 people paying £70
- 35 people paying £100

There is a Signal group chat you may join for the event here:
https://signal.group/#CjQKIAfn-Cz1WSdl8I79A3G4i9y0ksyBwadUZbObO_2SN8f3EhD2hWHm3IoZSyBxo5bAhaCL

If you have any questions reply to this email. :)

Love and mischief,
The Midsummer crew",
  ])
}

pub fn send_attendance_email(
  reference: String,
  name: String,
  email: String,
  config: Config,
) -> Nil {
  io.println(string.append("Sending attendance email for ", email))
  let content = attendance_email(reference, config)
  email.Email(
    to_name: name,
    to_address: email,
    subject: "Midsummer Night's Tea Party 2022 August",
    content: content,
  )
  |> email.send(config)
}

pub fn send_payment_confirmation_email(
  pence: Int,
  email: String,
  config: Config,
) -> Nil {
  io.println(string.append("Sending payment email for ", email))
  let content = payment_confirmation_email(pence)

  email.Email(
    to_name: "Midsummerer",
    to_address: email,
    subject: "Midsummer Night's Tea Party payment received",
    content: content,
  )
  |> email.send(config)
}
