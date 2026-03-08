alter table if exists dv_contact_messages
  add column if not exists kind text not null default 'contact',
  add column if not exists status text not null default 'open',
  add column if not exists user_id text null,
  add column if not exists subject text null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'dv_contact_messages_kind_check'
  ) then
    alter table dv_contact_messages
      add constraint dv_contact_messages_kind_check
      check (kind in ('contact', 'issue'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'dv_contact_messages_status_check'
  ) then
    alter table dv_contact_messages
      add constraint dv_contact_messages_status_check
      check (status in ('open', 'in_progress', 'resolved'));
  end if;
end $$;

update dv_contact_messages
set kind = 'contact'
where kind is null or btrim(kind) = '';

create index if not exists dv_contact_messages_kind_status_idx
  on dv_contact_messages (kind, status, created_at desc);

create index if not exists dv_contact_messages_user_id_idx
  on dv_contact_messages (user_id, created_at desc);
