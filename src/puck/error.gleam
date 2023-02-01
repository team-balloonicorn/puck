import sqlight

pub type Error {
  Database(sqlight.Error)
  EmailAlreadyInUse
}
