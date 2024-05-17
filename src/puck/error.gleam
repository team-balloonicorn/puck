import gleam/hackney
import sqlight

pub type Error {
  Database(sqlight.Error)
  Hackney(hackney.Error)
  EmailAlreadyInUse
  UnexpectedPushoverResponse(Int, String)
}
