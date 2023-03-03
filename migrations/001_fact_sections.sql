begin;

create table fact_sections (
  id integer primary key autoincrement not null,

  title text not null
    constraint non_empty_title check (length(title) > 0),

  blurb text not null,

  priority real not null default 0.0
) strict;

insert into fact_sections (title, blurb) values ('General', '');

create temporary table temp as select * from facts;

drop table facts;


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

insert into facts (
  id, summary, detail, priority, section_id
)
select
  id, summary, detail, priority, 1
from temp;

commit;
