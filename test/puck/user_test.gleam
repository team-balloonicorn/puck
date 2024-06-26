import gleam/option.{None, Some}
import gleam/string
import puck/database
import puck/error.{Database}
import puck/user.{User}
import tests

pub fn insert_new_users_test() {
  use db <- tests.with_connection

  let assert Ok(User(
    id: 1,
    name: "Jay",
    email: "jay@example.com",
    interactions: 0,
    is_admin: False,
    payment_reference: ref1,
    attended_before: None,
    support_network: "",
    support_network_attended: "",
    dietary_requirements: "",
    accessibility_requirements: "",
  )) = user.insert(db, "Jay", "jay@example.com")
  let assert "m-" <> _ = ref1

  let assert Ok(User(
    id: 2,
    name: "Al",
    email: "al@example.com",
    interactions: 0,
    is_admin: False,
    payment_reference: ref2,
    attended_before: None,
    support_network: "",
    support_network_attended: "",
    dietary_requirements: "",
    accessibility_requirements: "",
  )) = user.insert(db, "Al", "al@example.com")
  let assert "m-" <> _ = ref2

  let assert True = ref1 != ref2

  let assert Ok(User(
    id: 3,
    name: "Louis",
    email: "louis@example.com",
    interactions: 0,
    is_admin: False,
    payment_reference: _,
    attended_before: None,
    support_network: "",
    support_network_attended: "",
    dietary_requirements: "",
    accessibility_requirements: "",
  )) = user.insert(db, "Louis", "louis@example.com")
}

pub fn insert_lowercases_email_test() {
  use db <- tests.with_connection
  let assert Ok(User(
    id: 1,
    name: "Jay",
    email: "jay@example.com",
    interactions: 0,
    is_admin: False,
    payment_reference: _,
    attended_before: None,
    support_network: "",
    support_network_attended: "",
    dietary_requirements: "",
    accessibility_requirements: "",
  )) = user.insert(db, "Jay", "JAY@EXAMPLE.COM")
}

pub fn insert_invalid_email_test() {
  use db <- tests.with_connection
  let assert Error(error.Database(_)) = user.insert(db, "Blah", "not an email")
}

pub fn insert_invalid_name_test() {
  use db <- tests.with_connection
  let assert Error(error.Database(_)) = user.insert(db, "", "louis@example.com")
}

pub fn insert_already_inserted_test() {
  use db <- tests.with_connection

  let assert Ok(User(
    1,
    name: "Louis",
    email: "louis@example.com",
    interactions: 0,
    is_admin: False,
    payment_reference: _,
    attended_before: None,
    support_network: "",
    support_network_attended: "",
    dietary_requirements: "",
    accessibility_requirements: "",
  )) = user.insert(db, "Louis", "louis@example.com")

  let assert Error(error.EmailAlreadyInUse) =
    user.insert(db, "Louis", "louis@example.com")
}

pub fn get_by_id_incrementing_interaction_test() {
  use db <- tests.with_connection
  let assert Ok(User(id: 1, interactions: 0, ..)) =
    user.insert(db, "Louis", "louis@example.com")

  let assert Ok(Some(User(id: 1, interactions: 1, ..))) =
    user.get_and_increment_interaction(db, 1)
  let assert Ok(Some(User(id: 1, interactions: 2, ..))) =
    user.get_and_increment_interaction(db, 1)
  let assert Ok(Some(User(id: 1, interactions: 3, ..))) =
    user.get_and_increment_interaction(db, 1)
}

pub fn get_user_by_payment_reference_found_test() {
  use db <- tests.with_connection
  let assert Ok(user) = user.insert(db, "Louis", "louis@example.com")
  let assert Ok(Some(user2)) =
    user.get_user_by_payment_reference(db, user.payment_reference)
  let assert True = user.id == user2.id
}

pub fn get_user_by_payment_reference_case_insensitive_test() {
  use db <- tests.with_connection
  let assert Ok(user) = user.insert(db, "Louis", "louis@example.com")
  let ref = user.payment_reference

  let assert Ok(Some(user2)) =
    user.get_user_by_payment_reference(db, string.uppercase(ref))
  let assert True = user.id == user2.id

  let assert Ok(Some(user2)) =
    user.get_user_by_payment_reference(db, string.lowercase(ref))
  let assert True = user.id == user2.id
}

pub fn get_user_by_payment_reference_not_found_test() {
  use db <- tests.with_connection
  let assert Ok(None) =
    user.get_user_by_payment_reference(db, "m-12345678901234")
}

pub fn login_token_test() {
  use db <- tests.with_connection
  let assert Ok(user) = user.insert(db, "Louis", "louis@example.com")
  let id = user.id

  // Create a token and fetch it
  let assert Ok(Some(token)) = user.get_or_create_login_token(db, id)
  let assert Ok(Some(hash)) = user.get_login_token(db, id)

  // Verify it
  let assert True = token == hash
  let assert False = "other" == hash

  // Old tokens are not valid
  let sql = "update users set login_token_created_at = '2019-01-01 00:00:00'"
  let assert Ok(Nil) = database.exec(sql, db)
  let assert Ok(None) = user.get_login_token(db, id)
}

pub fn get_by_email_test() {
  use db <- tests.with_connection
  let assert Ok(None) = user.get_by_email(db, "jay@example.com")
  let assert Ok(User(id: 1, ..)) = user.insert(db, "Jay", "jay@example.com")
  let assert Ok(Some(User(id: 1, ..))) =
    user.get_by_email(db, "jay@example.com")
  let assert Ok(Some(User(id: 1, ..))) =
    user.get_by_email(db, "JAY@EXAMPLE.COM")
}
