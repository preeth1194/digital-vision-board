-- Track how the user obtained premium: 'store' | 'gift_code' | null (legacy/unknown)

ALTER TABLE dv_user_settings
  ADD COLUMN IF NOT EXISTS subscription_source text;
