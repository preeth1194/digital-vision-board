-- Gift code redemption for premium subscriptions

CREATE TABLE IF NOT EXISTS dv_gift_codes (
  id            serial PRIMARY KEY,
  code          text UNIQUE NOT NULL,
  plan_id       text NOT NULL DEFAULT 'dvb_premium_1year',
  duration_days integer NOT NULL DEFAULT 365,
  max_uses      integer NOT NULL DEFAULT 1,
  used_count    integer NOT NULL DEFAULT 0,
  active        boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS dv_gift_code_redemptions (
  id            serial PRIMARY KEY,
  code          text NOT NULL,
  canva_user_id text NOT NULL,
  redeemed_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(code, canva_user_id)
);

-- Seed test gift code (unlimited uses for testing)
INSERT INTO dv_gift_codes (code, plan_id, duration_days, max_uses)
VALUES ('PREETH111294', 'dvb_premium_1year', 365, 999)
ON CONFLICT (code) DO NOTHING;

INSERT INTO dv_gift_codes (code, plan_id, duration_days, max_uses)
VALUES ('THANKS', 'dvb_premium_1year', 365, 999)
ON CONFLICT (code) DO NOTHING;
