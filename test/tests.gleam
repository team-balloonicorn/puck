import sqlight
import puck/database

/// Open a unique in-memory database connection.
pub fn with_connection(f: fn(sqlight.Connection) -> a) -> a {
  database.with_connection("", f)
}
