-- Wizard recommendations with gender support.
-- Keyed by (core_value_id, category_key, gender_key).

create table if not exists dv_wizard_recommendations_v2 (
  core_value_id text not null,
  category_key text not null,
  gender_key text not null, -- 'unisex' | 'male' | 'female' | 'non_binary'
  category_label text not null,
  recommendations_json jsonb not null,
  source text,
  created_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (core_value_id, category_key, gender_key)
);

create index if not exists dv_wizard_recs_v2_updated_at_idx
  on dv_wizard_recommendations_v2 (updated_at desc);

-- Best-effort migration: copy v1 cache into v2 as unisex.
insert into dv_wizard_recommendations_v2 (
  core_value_id, category_key, gender_key, category_label, recommendations_json, source, created_by, created_at, updated_at
)
select
  core_value_id,
  category_key,
  'unisex' as gender_key,
  category_label,
  recommendations_json,
  source,
  created_by,
  created_at,
  updated_at
from dv_wizard_recommendations
on conflict (core_value_id, category_key, gender_key) do nothing;

