import gleam/option.{None, Some}
import puck/fact.{Fact, Section}
import tests

pub fn list_all_test() {
  use db <- tests.with_connection
  let assert Ok(Section(id: 1 as id, ..)) =
    fact.insert_section(db, "General", "")
  let assert Ok(_) = fact.insert(db, id, "One", "111", 0.0)
  let assert Ok(_) = fact.insert(db, id, "Two", "222", 0.0)
  let assert Ok(_) = fact.insert(db, id, "Three", "333", 1.0)
  let assert Ok(_) = fact.insert(db, id, "Four", "444", -1.0)
  let assert Ok(_) = fact.insert(db, id, "Five", "555", 10.0)
  let assert Ok([
    Fact(5, 1, "Five", "555", 10.0),
    Fact(3, 1, "Three", "333", 1.0),
    Fact(1, 1, "One", "111", 0.0),
    Fact(2, 1, "Two", "222", 0.0),
    Fact(4, 1, "Four", "444", -1.0),
  ]) = fact.list_all(db)
}

pub fn get_test() {
  use db <- tests.with_connection
  let assert Ok(Section(id: 1 as id, ..)) =
    fact.insert_section(db, "General", "")
  let assert Ok(None) = fact.get(db, 1)
  let assert Ok(Nil) = fact.insert(db, id, "One", "111", 0.0)
  let assert Ok(Some(Fact(1, 1, "One", "111", 0.0))) = fact.get(db, 1)
}

pub fn update_test() {
  use db <- tests.with_connection
  let assert Ok(Section(id: 1 as id, ..)) =
    fact.insert_section(db, "General", "")
  let assert Ok(Nil) = fact.insert(db, id, "One", "111", 0.0)
  let assert Ok(Some(Fact(1, 1, "One", "111", 0.0))) = fact.get(db, 1)
  let assert Ok(Nil) = fact.update(db, Fact(1, 1, "ONE", "ONNEE", 1.0))
  let assert Ok(Some(Fact(1, 1, "ONE", "ONNEE", 1.0))) = fact.get(db, 1)
}
