-- ================================================================
-- Digital Vision Board — Webapp Schema
-- Run this in your Supabase project SQL editor
--
-- IMPORTANT: This assumes your Render backend's DATABASE_URL points
-- to this same Supabase Postgres instance. If so, the trigger below
-- will automatically sync approved webapp submissions into the
-- dv_action_templates table that the mobile app reads from.
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- profiles (extends auth.users via trigger)
-- ────────────────────────────────────────────────────────────────
create table if not exists profiles (
  id          uuid primary key references auth.users on delete cascade,
  display_name text,
  avatar_url   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Auto-create a profile row whenever a new user signs up
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- ────────────────────────────────────────────────────────────────
-- preset_submissions  (webapp inbox — separate from dv_action_templates)
-- ────────────────────────────────────────────────────────────────
create table if not exists preset_submissions (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users on delete cascade,
  name              text not null,
  category          text not null check (category in ('skincare', 'workout', 'meal_prep', 'recipe')),
  steps_json        jsonb not null default '[]'::jsonb,
  preview_image_url text,
  status            text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  review_notes      text,
  reviewed_by       uuid references auth.users,
  reviewed_at       timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists preset_submissions_user_id_idx    on preset_submissions (user_id);
create index if not exists preset_submissions_status_idx     on preset_submissions (status);
create index if not exists preset_submissions_created_at_idx on preset_submissions (created_at desc);

-- ────────────────────────────────────────────────────────────────
-- contact_messages
-- ────────────────────────────────────────────────────────────────
create table if not exists contact_messages (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  email      text not null,
  message    text not null,
  created_at timestamptz not null default now()
);

-- ────────────────────────────────────────────────────────────────
-- Row Level Security
-- ────────────────────────────────────────────────────────────────

-- profiles
alter table profiles enable row level security;

create policy "Users can view own profile"
  on profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- preset_submissions
alter table preset_submissions enable row level security;

create policy "Users can insert own submissions"
  on preset_submissions for insert
  with check (auth.uid() = user_id);

create policy "Users can view own submissions"
  on preset_submissions for select
  using (auth.uid() = user_id);

-- Note: Admin reads/updates use the service role key (createAdminClient)
-- which bypasses RLS entirely — no additional admin policies needed.

-- contact_messages — public insert (anyone can contact)
alter table contact_messages enable row level security;

create policy "Anyone can submit a contact message"
  on contact_messages for insert
  with check (true);

-- ────────────────────────────────────────────────────────────────
-- Sync trigger: approved webapp submissions → dv_action_templates
--
-- When the webapp admin approves a preset_submission, this trigger
-- automatically upserts it into dv_action_templates so the mobile
-- app's /action-templates endpoint returns it immediately.
--
-- IDs are prefixed with 'webapp_' to avoid collisions with mobile-
-- submitted or official templates.
--
-- PREREQUISITE: dv_action_templates must already exist in this DB.
-- Run the Render backend's sql/010_action_templates.sql first if not.
-- ────────────────────────────────────────────────────────────────
create or replace function sync_preset_submission_to_action_templates()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  -- Approval: publish to mobile app
  if new.status = 'approved' and (old.status is distinct from 'approved') then
    insert into dv_action_templates (
      id,
      name,
      category,
      schema_version,
      template_version,
      status,
      is_public,
      is_official,
      set_key,
      steps_json,
      metadata_json,
      created_by,
      reviewed_by,
      reviewed_at,
      review_notes
    ) values (
      'webapp_' || new.id::text,
      new.name,
      new.category,
      1,
      1,
      'approved',
      true,
      false,
      null,
      new.steps_json,
      '{}'::jsonb,
      new.user_id::text,
      coalesce(new.reviewed_by::text, 'admin'),
      coalesce(new.reviewed_at, now()),
      new.review_notes
    )
    on conflict (id) do update set
      name         = excluded.name,
      category     = excluded.category,
      steps_json   = excluded.steps_json,
      status       = 'approved',
      is_public    = true,
      reviewed_by  = excluded.reviewed_by,
      reviewed_at  = excluded.reviewed_at,
      review_notes = excluded.review_notes,
      updated_at   = now();
  end if;

  -- Rejection after prior approval: hide from mobile app
  if new.status = 'rejected' and old.status = 'approved' then
    update dv_action_templates
    set
      status     = 'rejected',
      is_public  = false,
      updated_at = now()
    where id = 'webapp_' || new.id::text;
  end if;

  return new;
end;
$$;

drop trigger if exists sync_preset_to_mobile on preset_submissions;
create trigger sync_preset_to_mobile
  after update on preset_submissions
  for each row
  execute function sync_preset_submission_to_action_templates();

-- ────────────────────────────────────────────────────────────────
-- Storage bucket
-- ────────────────────────────────────────────────────────────────
-- Create in Supabase dashboard → Storage:
--
--   Bucket name : preset-previews
--   Public      : true
--   File size   : 5 MB
--   MIME types  : image/png, image/jpeg, image/webp
--
-- Storage RLS policies:
--   SELECT (public read):  bucket_id = 'preset-previews'
--   INSERT (auth users):   bucket_id = 'preset-previews' AND auth.role() = 'authenticated'
