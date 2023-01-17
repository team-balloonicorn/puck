import tests
import gleam/string
import puck/user.{Application, User}
import gleam/option.{None, Some}
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

pub fn get_by_id_incrementing_interactiont_test() {
  use db <- tests.with_connection
  assert Ok(User(id: 1, interactions: 0, ..)) =
    user.get_or_insert_by_email(db, "louis@example.com")

  assert Ok(Some(User(id: 1, interactions: 1, ..))) =
    user.get_and_increment_interaction(db, 1)
  assert Ok(Some(User(id: 1, interactions: 2, ..))) =
    user.get_and_increment_interaction(db, 1)
  assert Ok(Some(User(id: 1, interactions: 3, ..))) =
    user.get_and_increment_interaction(db, 1)

  assert Ok(User(interactions: 3, ..)) =
    user.get_or_insert_by_email(db, "louis@example.com")
}

pub fn insert_application_test() {
  use db <- tests.with_connection
  assert Ok(user) = user.get_or_insert_by_email(db, "louis@example.com")

  assert Ok(Application(id: 1, payment_reference: reference, user_id: uid)) =
    user.get_or_insert_application(db, user.id)

  assert 14 = string.length(reference)
  assert True = string.starts_with(reference, "m-")
  assert True = uid == user.id
}

pub fn get_user_by_payment_reference_found_test() {
  use db <- tests.with_connection
  assert Ok(user) = user.get_or_insert_by_email(db, "louis@example.com")
  assert Ok(app) = user.get_or_insert_application(db, user.id)
  assert Ok(Some(user2)) =
    user.get_user_by_payment_reference(db, app.payment_reference)
  assert True = user.id == user2.id
}

pub fn get_user_by_payment_reference_case_insensitive_test() {
  use db <- tests.with_connection
  assert Ok(user) = user.get_or_insert_by_email(db, "louis@example.com")
  assert Ok(app) = user.get_or_insert_application(db, user.id)
  let ref = app.payment_reference

  assert Ok(Some(user2)) =
    user.get_user_by_payment_reference(db, string.uppercase(ref))
  assert True = user.id == user2.id

  assert Ok(Some(user2)) =
    user.get_user_by_payment_reference(db, string.lowercase(ref))
  assert True = user.id == user2.id
}

pub fn get_user_by_payment_reference_not_found_test() {
  use db <- tests.with_connection
  assert Ok(None) = user.get_user_by_payment_reference(db, "m-12345678901234")
}
