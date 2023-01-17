import bcrypter
import gleam/string

pub fn hash_and_verify_test() {
  let hash = bcrypter.hash("password")

  // The hash has certain properties
  assert True = hash != "password"
  assert 60 = string.length(hash)

  // The hash can be verified
  assert True = bcrypter.verify("password", hash)
  assert False = bcrypter.verify("Password", hash)
  assert False = bcrypter.verify("password ", hash)
  assert False = bcrypter.verify("passwor", hash)
}
