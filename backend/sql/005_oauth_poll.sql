-- OAuth poll store for Canva panel connections (avoids window.opener postMessage)

create table if not exists dv_oauth_poll_tokens (
  poll_token text primary key,
  dv_token text,
  canva_user_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists dv_oauth_poll_tokens_updated_at_idx on dv_oauth_poll_tokens (updated_at desc);

