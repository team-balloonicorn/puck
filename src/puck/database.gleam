import gleam/dynamic
import gleam/option.{type Option}
import gleam/result
import puck/error.{type Error}
import sqlight

pub type Connection =
  sqlight.Connection

const connection_config = "
pragma foreign_keys = on
pragma journal_mode=wal;
pragma synchronous=normal;
pragma mmap_size = 134217728;
pragma journal_size_limit = 27103364;
pragma cache_size=2000;
"

pub fn with_connection(path: String, f: fn(sqlight.Connection) -> a) -> a {
  use db <- sqlight.with_connection(path)

  // Enable configuration we want for all connections
  let assert Ok(_) = sqlight.exec(connection_config, db)

  f(db)
}

pub fn query(
  sql: String,
  connection: sqlight.Connection,
  arguments: List(sqlight.Value),
  decoder: dynamic.Decoder(t),
) -> Result(List(t), Error) {
  sqlight.query(sql, connection, arguments, decoder)
  |> result.map_error(error.Database)
}

pub fn exec(sql: String, connection: sqlight.Connection) -> Result(Nil, Error) {
  sqlight.exec(sql, connection)
  |> result.map_error(error.Database)
}

pub fn one(
  sql: String,
  connection: sqlight.Connection,
  arguments: List(sqlight.Value),
  decoder: dynamic.Decoder(t),
) -> Result(t, Error) {
  query(sql, connection, arguments, decoder)
  |> result.map(fn(rows) {
    let assert [row] = rows
    row
  })
}

pub fn maybe_one(
  sql: String,
  connection: sqlight.Connection,
  arguments: List(sqlight.Value),
  decoder: dynamic.Decoder(t),
) -> Result(Option(t), Error) {
  query(sql, connection, arguments, decoder)
  |> result.map(fn(rows) {
    case rows {
      [] -> option.None
      [row] -> option.Some(row)
      _ -> panic as "Expected 0 or 1 rows"
    }
  })
}

pub fn migrate(db: sqlight.Connection) -> Nil {
  let assert Ok(_) =
    sqlight.exec(
      "
create table if not exists users (
  id integer primary key autoincrement not null,

  name text not null
    constraint non_empty_name check (length(name) > 0),

  email text not null unique
    constraint valid_email check (email like '%@%'),

  interactions integer not null default 0
    constraint positive_interactions check (interactions >= 0),

  is_admin integer not null default 0
    constraint valid_is_admin check (is_admin in (0, 1)),

  login_token text unique,

  login_token_created_at text
    constraint valid_login_token_created_at check (
      login_token_created_at is null 
      or datetime(login_token_created_at) not null
    ),

  payment_reference text not null unique collate nocase
    constraint valid_payment_reference check (
      length(payment_reference) = 14 and payment_reference like 'm-%'
    ),

  attended_before integer
    constraint valid_attended_before check (is_admin in (0, 1)),

  support_network text not null default '',
  support_network_attended text not null default '',
  dietary_requirements text not null default '',
  accessibility_requirements text not null default ''
) strict;

create table if not exists payments (
  id text primary key not null,

  created_at text not null
    constraint valid_date check (datetime(created_at) not null),

  counterparty text not null,

  amount integer not null
    constraint positive_amount check (amount > 0),

  reference text not null
) strict;

create table if not exists facts (
  id integer primary key autoincrement not null,

  summary text not null
    constraint non_empty_summary check (length(summary) > 0),

  detail text not null
    constraint non_empty_detail check (length(detail) > 0),

  priority real not null default 0.0,

  section_id integer not null,

  foreign key (section_id) references fact_sections(id)
) strict;

create table if not exists fact_sections (
  id integer primary key autoincrement not null,

  title text not null
    constraint non_empty_title check (length(title) > 0),

  blurb text not null,

  priority real not null default 0.0
) strict;
",
      db,
    )

  Nil
}
