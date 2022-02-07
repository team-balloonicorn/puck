import gleam/list
import gleam/string
import gleam/result

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

  // TODO: generate reference
  let reference = "123"

  Ok(Attendee(
    name: name,
    email: email,
    attended: attended,
    pal: pal,
    pal_attended: pal_attended,
    diet: diet,
    accessibility: accessibility,
    contribution: contribution,
    reference: reference,
  ))
}

fn radio_button(
  query: List(#(String, String)),
  name: String,
) -> Result(Bool, Nil) {
  try value = list.key_find(query, name)
  case value {
    "yes" -> Ok(True)
    "no" -> Ok(True)
    _ -> Error(Nil)
  }
}
