import bcrypter
import gleam/map
import gleam/option.{None, Some}
import gleam/string
import puck/error.{Database}
import puck/user.{Application, User}
import tests

pub fn insert_new_users_test() {
  use db <- tests.with_connection

  assert Ok(User(id: 1, name: "Jay", email: "jay@example.com", interactions: 0)) =
    user.insert(db, "Jay", "jay@example.com")

  assert Ok(User(id: 2, name: "Al", email: "al@example.com", interactions: 0)) =
    user.insert(db, "Al", "al@example.com")

  assert Ok(User(
    id: 3,
    name: "Louis",
    email: "louis@example.com",
    interactions: 0,
  )) = user.insert(db, "Louis", "louis@example.com")
}

pub fn insert_invalid_email_test() {
  use db <- tests.with_connection
  assert Error(error.Database(_)) = user.insert(db, "Blah", "not an email")
}

pub fn insert_invalid_name_test() {
  use db <- tests.with_connection
  assert Error(error.Database(_)) = user.insert(db, "", "louis@example.com")
}

pub fn insert_already_inserted_test() {
  use db <- tests.with_connection

  assert Ok(User(1, name: "Louis", email: "louis@example.com", interactions: 0)) =
    user.insert(db, "Louis", "louis@example.com")

  assert Error(error.EmailAlreadyInUse) =
    user.insert(db, "Louis", "louis@example.com")
}

pub fn get_by_id_incrementing_interaction_test() {
  use db <- tests.with_connection
  assert Ok(User(id: 1, interactions: 0, ..)) =
    user.insert(db, "Louis", "louis@example.com")

  assert Ok(Some(User(id: 1, interactions: 1, ..))) =
    user.get_and_increment_interaction(db, 1)
  assert Ok(Some(User(id: 1, interactions: 2, ..))) =
    user.get_and_increment_interaction(db, 1)
  assert Ok(Some(User(id: 1, interactions: 3, ..))) =
    user.get_and_increment_interaction(db, 1)
}

pub fn insert_application_test() {
  use db <- tests.with_connection
  assert Ok(user) = user.insert(db, "Louis", "louis@example.com")

  assert Ok(Application(
    id: 1,
    payment_reference: reference,
    user_id: uid,
    answers: answers,
  )) =
    user.insert_application(
      db,
      user.id,
      map.from_list([#("a", "b"), #("c", "d")]),
    )

  assert 14 = string.length(reference)
  assert True = string.starts_with(reference, "m-")
  assert True = uid == user.id
  assert [#("a", "b"), #("c", "d")] = map.to_list(answers)
}

pub fn insert_application_already_existing_test() {
  use db <- tests.with_connection
  assert Ok(user) = user.insert(db, "Louis", "louis@example.com")

  assert Ok(Application(id: 1, payment_reference: reference1, user_id: uid1, ..)) =
    user.insert_application(
      db,
      user.id,
      map.from_list([#("a", "b"), #("c", "d")]),
    )
  assert Ok(Application(
    id: 1,
    payment_reference: reference2,
    user_id: uid2,
    answers: answers,
  )) =
    user.insert_application(
      db,
      user.id,
      map.from_list([#("a", "changed"), #("c", "d"), #("e", "f")]),
    )

  assert True = reference1 == reference2
  assert True = uid1 == uid2
  assert [#("a", "changed"), #("c", "d"), #("e", "f")] = map.to_list(answers)
}

pub fn get_application_test() {
  use db <- tests.with_connection
  assert Ok(user) = user.insert(db, "Louis", "louis@example.com")

  assert Ok(None) = user.get_application(db, user.id)

  assert Ok(application1) =
    user.insert_application(db, user.id, map.from_list([#("a", "b")]))

  assert Ok(Some(application2)) = user.get_application(db, user.id)

  assert True = application1 == application2
}

pub fn get_user_by_payment_reference_found_test() {
  use db <- tests.with_connection
  assert Ok(user) = user.insert(db, "Louis", "louis@example.com")
  assert Ok(app) = user.insert_application(db, user.id, map.new())
  assert Ok(Some(user2)) =
    user.get_user_by_payment_reference(db, app.payment_reference)
  assert True = user.id == user2.id
}

pub fn get_user_by_payment_reference_case_insensitive_test() {
  use db <- tests.with_connection
  assert Ok(user) = user.insert(db, "Louis", "louis@example.com")
  assert Ok(app) = user.insert_application(db, user.id, map.new())
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

pub fn login_token_hash_test() {
  use db <- tests.with_connection
  assert Ok(user) = user.insert(db, "Louis", "louis@example.com")
  let id = user.id

  // Create a token and fetch it
  assert Ok(Some(token)) = user.create_login_token(db, id)
  assert Ok(Some(hash)) = user.get_login_token_hash(db, id)

  // Verify it
  assert True = bcrypter.verify(token, hash)
  assert False = bcrypter.verify("other", hash)

  // Delete it
  assert Ok(True) = user.delete_login_token_hash(db, id)
  // It is gone!
  assert Ok(None) = user.get_login_token_hash(db, id)
  // The user isn't though
  assert Ok(Some(User(id: 1, ..))) = user.get_and_increment_interaction(db, id)
}
