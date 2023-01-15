import puck/config.{Config}
import sqlight

pub fn with_connection(path: String, f: fn(sqlight.Connection) -> a) -> a {
  use db <- sqlight.with_connection(path)

  // Enable configuration we want for all connections
  assert Ok(_) = sqlight.exec("pragma foreign_keys = on;", db)

  f(db)
}

pub fn migrate(db: sqlight.Connection) -> Nil {
  assert Ok(_) =
    sqlight.exec(
      "
create table if not exists users (
  id integer primary key autoincrement not null,

  email text not null unique
    constraint valid_email check (email like '%@%'),

  interactions integer not null default 0
    constraint positive_interactions check (interactions >= 0)
) strict;

create table if not exists applications (
  id integer primary key autoincrement not null,

  user_id integer not null,

  payment_reference text not null unique
    constraint valid_payment_reference check (
      length(payment_reference) = 14 and payment_reference like 'm-%'
    ),

  foreign key (user_id) references users (id)
) strict;

create table if not exists payments (
  id integer primary key autoincrement not null,

  created_at text not null
    constraint valid_date check (created_at like '____-__-__ __:__:__'),

  amount integer not null
    constraint positive_amount check (amount > 0),

  reference text not null
) strict;
",
      db,
    )

  Nil
}
