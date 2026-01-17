-- Guest auth support (dvToken expiry for guest users)

alter table if exists dv_users
  add column if not exists is_guest boolean not null default false;

alter table if exists dv_users
  add column if not exists guest_expires_at timestamptz;

create index if not exists dv_users_guest_expires_at_idx on dv_users (guest_expires_at);

