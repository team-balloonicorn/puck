import puck/fact.{Fact}
import tests

pub fn list_all_test() {
  use db <- tests.with_connection
  assert Ok(_) = fact.insert(db, "One", "111", 0.0)
  assert Ok(_) = fact.insert(db, "Two", "222", 0.0)
  assert Ok(_) = fact.insert(db, "Three", "333", 1.0)
  assert Ok(_) = fact.insert(db, "Four", "444", -1.0)
  assert Ok(_) = fact.insert(db, "Five", "555", 10.0)
  assert Ok([
    Fact(5, "Five", "555", 10.0),
    Fact(3, "Three", "333", 1.0),
    Fact(1, "One", "111", 0.0),
    Fact(2, "Two", "222", 0.0),
    Fact(4, "Four", "444", -1.0),
  ]) = fact.list_all(db)
}
