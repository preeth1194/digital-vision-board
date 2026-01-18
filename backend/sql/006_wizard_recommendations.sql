-- Wizard defaults + recommended goals/habits (global cache)

create table if not exists dv_wizard_defaults (
  id text primary key,
  defaults_json jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Cache recommendations keyed by (core_value_id, normalized category key).
-- category_key is lowercased + trimmed + collapsed whitespace on the server.
create table if not exists dv_wizard_recommendations (
  core_value_id text not null,
  category_key text not null,
  category_label text not null,
  recommendations_json jsonb not null,
  source text,
  created_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (core_value_id, category_key)
);

create index if not exists dv_wizard_recommendations_updated_at_idx
  on dv_wizard_recommendations (updated_at desc);

