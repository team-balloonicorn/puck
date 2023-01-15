import tests
import puck/user.{User}
import puck/error

pub fn get_or_insert_by_email_new_users_test() {
  use db <- tests.with_connection

  assert Ok(User(id: 1, email: "jay@example.com", interactions: 0)) =
    user.get_or_insert_by_email(db, "jay@example.com")

  assert Ok(User(id: 2, email: "al@example.com", interactions: 0)) =
    user.get_or_insert_by_email(db, "al@example.com")

  assert Ok(User(id: 3, email: "louis@example.com", interactions: 0)) =
    user.get_or_insert_by_email(db, "louis@example.com")
}

pub fn get_or_insert_by_email_invalid_email_test() {
  use db <- tests.with_connection
  assert Error(error.SqlightError(_)) =
    user.get_or_insert_by_email(db, "not an email")
}

pub fn get_or_insert_by_email_already_inserted_test() {
  use db <- tests.with_connection

  assert Ok(User(id: 1, email: "louis@example.com", interactions: 0)) =
    user.get_or_insert_by_email(db, "louis@example.com")

  assert Ok(User(id: 1, email: "louis@example.com", interactions: 0)) =
    user.get_or_insert_by_email(db, "louis@example.com")

  assert Ok(User(id: 1, email: "louis@example.com", interactions: 0)) =
    user.get_or_insert_by_email(db, "louis@example.com")
}

pub fn increment_interaction_count_test() {
  use db <- tests.with_connection
  assert Ok(User(id: 1, interactions: 0, ..)) =
    user.get_or_insert_by_email(db, "louis@example.com")

  assert Ok(Nil) = user.increment_interaction_count(db, 1)
  assert Ok(Nil) = user.increment_interaction_count(db, 1)
  assert Ok(Nil) = user.increment_interaction_count(db, 1)

  assert Ok(User(interactions: 3, ..)) =
    user.get_or_insert_by_email(db, "louis@example.com")
}
