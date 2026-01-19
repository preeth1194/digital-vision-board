-- Add gender to user settings (default: prefer_not_to_say)

alter table dv_user_settings
  add column if not exists gender text not null default 'prefer_not_to_say';

