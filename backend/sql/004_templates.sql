-- Board templates + template images (admin-published, v1)

create table if not exists dv_template_images (
  id text primary key,
  created_by text not null,
  content_type text not null,
  bytes bytea not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists dv_template_images_created_by_idx on dv_template_images (created_by, created_at desc);

create table if not exists dv_board_templates (
  id text primary key,
  name text not null,
  kind text not null, -- 'goal_canvas' | 'grid'
  template_json jsonb not null,
  preview_image_id text references dv_template_images(id) on delete set null,
  created_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists dv_board_templates_kind_updated_at_idx on dv_board_templates (kind, updated_at desc);
create index if not exists dv_board_templates_created_by_updated_at_idx on dv_board_templates (created_by, updated_at desc);

