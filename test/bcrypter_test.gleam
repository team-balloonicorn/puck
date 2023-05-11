import bcrypter
import gleam/string

pub fn hash_and_verify_test() {
  let hash = bcrypter.hash("password")

  // The hash has certain properties
  let assert True = hash != "password"
  let assert 60 = string.length(hash)

  // The hash can be verified
  let assert True = bcrypter.verify("password", hash)
  let assert False = bcrypter.verify("Password", hash)
  let assert False = bcrypter.verify("password ", hash)
  let assert False = bcrypter.verify("passwor", hash)
}
