import bcrypter
import gleam/string

pub fn hash_and_compare_test() {
  let hash = bcrypter.hash("password")

  // The hash has certain properties
  assert True = hash != "password"
  assert 60 = string.length(hash)

  // The hash can be verified
  assert True = bcrypter.compare("password", hash)
  assert False = bcrypter.compare("Password", hash)
  assert False = bcrypter.compare("password ", hash)
  assert False = bcrypter.compare("passwor", hash)
}
