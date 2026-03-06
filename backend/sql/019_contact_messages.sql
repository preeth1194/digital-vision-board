create table if not exists dv_contact_messages (
  id bigserial primary key,
  name text not null,
  email text not null,
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists dv_contact_messages_created_at_idx
  on dv_contact_messages (created_at desc);
