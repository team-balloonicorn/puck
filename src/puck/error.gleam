import sqlight

pub type Error {
  SqlightError(sqlight.Error)
}
