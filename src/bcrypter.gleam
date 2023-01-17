import gleam/erlang/charlist.{Charlist}
import gleam/crypto
import gleam/string

pub fn hash(password: String) -> String {
  let salt = generate_salt()
  hash_with_salt(password, salt)
}

pub fn compare(password: String, hash: String) -> Bool {
  let salt = string.slice(hash, at_index: 0, length: 29)
  let hashed = hash_with_salt(password, salt)
  crypto.secure_compare(<<hash:utf8>>, <<hashed:utf8>>)
}

external type BcrypeErlangError

fn generate_salt() -> String {
  assert Ok(salt) = gen_salt()
  charlist.to_string(salt)
}

fn hash_with_salt(password: String, salt: String) -> String {
  assert Ok(hash) = hashpw(password, salt)
  charlist.to_string(hash)
}

external fn gen_salt() -> Result(Charlist, BcrypeErlangError) =
  "bcrypt" "gen_salt"

external fn hashpw(String, String) -> Result(Charlist, BcrypeErlangError) =
  "bcrypt" "hashpw"
