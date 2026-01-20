-- Add Spotify OAuth token columns to dv_users table

alter table dv_users
  add column if not exists spotify_access_token text,
  add column if not exists spotify_refresh_token text,
  add column if not exists spotify_expires_in integer,
  add column if not exists spotify_token_type text,
  add column if not exists spotify_obtained_at bigint,
  add column if not exists spotify_scope text;
