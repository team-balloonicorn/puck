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
import gleam/option.{Option}
import gleam/gen_smtp
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
    name: escape(name),
    email: escape(email),
    attended: attended,
    pal: escape(pal),
    pal_attended: pal_attended,
    diet: escape(diet),
    accessibility: escape(accessibility),
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

fn escape(input: String) -> String {
  case string.starts_with(input, "=") {
    True -> string.append(" ", input)
    False -> input
  }
}

pub type NotificationError {
  EmailSendingFailed
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

pub fn attendance_email(
  amount: Int,
  reference: String,
  config: Config,
) -> String {
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
- Amount: £",
    int.to_string(amount),
    "

If you have any questions reply to this email. :)

Thanks,
The Midsummer crew",
  ])
}

pub fn send_attendance_email(
  attendee: Attendee,
  config: Config,
) -> Result(Nil, NotificationError) {
  case contribtion_amount(attendee) {
    option.None -> Ok(Nil)

    option.Some(amount) -> {
      io.println(string.append("Sending attendance email for ", attendee.name))
      let content = attendance_email(amount, attendee.reference, config)
      gen_smtp.Email(
        from_email: config.smtp_from_email,
        from_name: config.smtp_from_name,
        to: [attendee.email],
        subject: "Midsummer Night's Tea Party 2022",
        content: content,
      )
      |> email.send(config)
      |> result.replace_error(EmailSendingFailed)
    }
  }
}

pub fn send_payment_confirmation_email(
  pence: Int,
  email_address: String,
  config: Config,
) -> Result(Nil, NotificationError) {
  io.println(string.append("Sending payment email for ", email_address))
  let content = payment_confirmation_email(pence)

  gen_smtp.Email(
    from_email: config.smtp_from_email,
    from_name: config.smtp_from_name,
    to: [email_address],
    subject: "Midsummer Night's Tea Party payment received",
    content: content,
  )
  |> email.send(config)
  |> result.replace_error(EmailSendingFailed)
}
