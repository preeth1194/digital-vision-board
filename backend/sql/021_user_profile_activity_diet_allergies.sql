-- Extended profile fields (client already sent these; now persisted server-side)

alter table dv_user_settings add column if not exists activity_level text;
alter table dv_user_settings add column if not exists diet_preference text;
alter table dv_user_settings add column if not exists allergies jsonb;
