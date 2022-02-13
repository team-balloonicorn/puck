import puck/attendee.{Attendee}
import gleeunit/should
import gleam/string

pub fn from_query_test() {
  assert Ok(Attendee(
    name: name,
    email: email,
    attended: attended,
    pal: pal,
    pal_attended: pal_attended,
    diet: diet,
    accessibility: accessibility,
    contribution: contribution,
    reference: reference,
  )) =
    attendee.from_query([
      #("email", "email@example.com"),
      #("dietary-requirements", "veggie food"),
      #("attended", "yes"),
      #("name", "Bob"),
      #("pal", "George"),
      #("pal-attended", "no"),
      #("accessibility-requirements", ""),
      #("contribution", "120"),
    ])

  name
  |> should.equal("Bob")

  pal
  |> should.equal("George")

  email
  |> should.equal("email@example.com")

  attended
  |> should.be_true

  pal_attended
  |> should.be_false

  diet
  |> should.equal("veggie food")

  reference
  |> string.length
  |> should.equal(12)

  reference
  |> string.starts_with("m-")
  |> should.be_true

  contribution
  |> should.equal(attendee.Contribute120)

  accessibility
  |> should.equal("")
}
