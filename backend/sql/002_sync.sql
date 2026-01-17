-- Sync schema: boards/config + recent completion logs + user settings

create table if not exists dv_user_settings (
  canva_user_id text primary key references dv_users(canva_user_id) on delete cascade,
  home_timezone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists dv_boards (
  canva_user_id text not null references dv_users(canva_user_id) on delete cascade,
  board_id text not null,
  board_json jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (canva_user_id, board_id)
);

create index if not exists dv_boards_canva_user_id_updated_at_idx on dv_boards (canva_user_id, updated_at desc);

-- Habit completion log (recent-only retention enforced at API level initially)
create table if not exists dv_habit_completions (
  canva_user_id text not null references dv_users(canva_user_id) on delete cascade,
  board_id text not null,
  component_id text not null,
  habit_id text not null,
  logical_date date not null,
  rating integer,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (canva_user_id, board_id, component_id, habit_id, logical_date)
);

create index if not exists dv_habit_completions_user_date_idx on dv_habit_completions (canva_user_id, logical_date desc);
create index if not exists dv_habit_completions_user_habit_date_idx on dv_habit_completions (canva_user_id, habit_id, logical_date desc);

-- Checklist/task completion events (per-item per-day; used for checklists and tasks)
create table if not exists dv_checklist_events (
  canva_user_id text not null references dv_users(canva_user_id) on delete cascade,
  board_id text not null,
  component_id text not null,
  task_id text not null,
  item_id text not null,
  logical_date date not null,
  rating integer,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (canva_user_id, board_id, component_id, task_id, item_id, logical_date)
);

create index if not exists dv_checklist_events_user_date_idx on dv_checklist_events (canva_user_id, logical_date desc);

