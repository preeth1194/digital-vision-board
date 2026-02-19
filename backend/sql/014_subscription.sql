-- Subscription status synced from client (App Store / Play Store)

alter table dv_user_settings add column if not exists subscription_plan_id text;
alter table dv_user_settings add column if not exists subscription_active boolean not null default false;
alter table dv_user_settings add column if not exists subscription_updated_at timestamptz;
