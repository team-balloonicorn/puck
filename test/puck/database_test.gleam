import puck/database

pub fn database_migration_test() {
  use db <- database.with_connection("")
  database.migrate(db)
  // Hey cool, it didn't crash
}
