-- ================================================================
-- 018_remove_canva.sql
-- Remove legacy Canva OAuth columns/tables and rename the
-- internal "canva_user_id" column to "user_id" across all tables.
-- ================================================================

-- Drop unused Canva OAuth token columns from dv_users
alter table dv_users drop column if exists canva_access_token;
alter table dv_users drop column if exists canva_refresh_token;
alter table dv_users drop column if exists canva_expires_in;
alter table dv_users drop column if exists canva_token_type;
alter table dv_users drop column if exists canva_obtained_at;
alter table dv_users drop column if exists canva_scope;

-- Drop Canva team ID (always null)
alter table dv_users drop column if exists team_id;

-- Drop Canva PKCE / OAuth poll tables (no endpoints use them)
drop table if exists dv_pkce_states;
drop table if exists dv_oauth_poll_tokens;

-- ── Rename canva_user_id → user_id across all tables ────────────
-- Postgres automatically updates FK constraints on column rename.

do $$
begin
  if exists (select 1 from information_schema.columns
             where table_name = 'dv_users' and column_name = 'canva_user_id') then
    alter table dv_users rename column canva_user_id to user_id;
  end if;
  if exists (select 1 from information_schema.columns
             where table_name = 'dv_user_settings' and column_name = 'canva_user_id') then
    alter table dv_user_settings rename column canva_user_id to user_id;
  end if;
  if exists (select 1 from information_schema.columns
             where table_name = 'dv_boards' and column_name = 'canva_user_id') then
    alter table dv_boards rename column canva_user_id to user_id;
  end if;
  if exists (select 1 from information_schema.columns
             where table_name = 'dv_habit_completions' and column_name = 'canva_user_id') then
    alter table dv_habit_completions rename column canva_user_id to user_id;
  end if;
  if exists (select 1 from information_schema.columns
             where table_name = 'dv_checklist_events' and column_name = 'canva_user_id') then
    alter table dv_checklist_events rename column canva_user_id to user_id;
  end if;
end $$;

-- Only rename if the table exists (added in later migrations)
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_name = 'dv_affirmations' and column_name = 'canva_user_id') then
    alter table dv_affirmations rename column canva_user_id to user_id;
  end if;
  if exists (select 1 from information_schema.columns
             where table_name = 'dv_gift_code_redemptions' and column_name = 'canva_user_id') then
    alter table dv_gift_code_redemptions rename column canva_user_id to user_id;
  end if;
end $$;
