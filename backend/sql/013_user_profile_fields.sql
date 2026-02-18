-- Add profile fields to user settings

alter table dv_user_settings add column if not exists display_name text;
alter table dv_user_settings add column if not exists weight_kg real;
alter table dv_user_settings add column if not exists height_cm real;
alter table dv_user_settings add column if not exists date_of_birth date;
