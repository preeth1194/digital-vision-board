-- Digital Vision Board backend schema (Postgres)

create table if not exists dv_users (
  canva_user_id text primary key,
  team_id text,
  dv_token text unique not null,

  canva_access_token text,
  canva_refresh_token text,
  canva_expires_in integer,
  canva_token_type text,
  canva_obtained_at bigint,
  canva_scope text,

  habits jsonb not null default '[]'::jsonb,
  packages jsonb not null default '[]'::jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists dv_users_dv_token_idx on dv_users (dv_token);

create table if not exists dv_pkce_states (
  state text primary key,
  record jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists dv_pkce_states_created_at_idx on dv_pkce_states (created_at);

