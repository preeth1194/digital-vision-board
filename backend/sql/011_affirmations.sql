-- Affirmations schema, v1
-- Stores user affirmations organized by category from vision boards

create table if not exists dv_affirmations (
  canva_user_id text not null references dv_users(canva_user_id) on delete cascade,
  affirmation_id text not null,
  category text,
  text text not null,
  is_pinned boolean not null default false,
  is_custom boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (canva_user_id, affirmation_id)
);

create index if not exists dv_affirmations_user_category_idx 
  on dv_affirmations (canva_user_id, category);

create index if not exists dv_affirmations_user_pinned_idx 
  on dv_affirmations (canva_user_id, is_pinned desc, created_at desc);

create index if not exists dv_affirmations_user_updated_idx 
  on dv_affirmations (canva_user_id, updated_at desc);
