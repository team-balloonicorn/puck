import sqlight
import gleam/hackney

pub type Error {
  Database(sqlight.Error)
  Hackney(hackney.Error)
  EmailAlreadyInUse
  UnexpectedPushoverResponse(Int, String)
}
