create table if not exists dv_action_templates (
  id text primary key,
  name text not null,
  category text not null check (category in ('skincare', 'workout', 'meal_prep', 'recipe')),
  schema_version int not null default 1,
  template_version int not null default 1,
  status text not null default 'draft' check (status in ('draft', 'submitted', 'approved', 'rejected')),
  is_public boolean not null default false,
  is_official boolean not null default false,
  set_key text,
  steps_json jsonb not null,
  metadata_json jsonb not null default '{}'::jsonb,
  created_by text not null,
  reviewed_by text,
  review_notes text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists dv_action_templates_category_status_updated_idx
  on dv_action_templates (category, status, updated_at desc);
create index if not exists dv_action_templates_created_by_updated_idx
  on dv_action_templates (created_by, updated_at desc);
create index if not exists dv_action_templates_set_key_idx
  on dv_action_templates (set_key);

insert into dv_action_templates (
  id, name, category, schema_version, template_version, status, is_public, is_official, set_key, steps_json, metadata_json, created_by
)
values
  (
    'default_set_beginner_skincare',
    'Beginner AM/PM Skincare',
    'skincare',
    1,
    1,
    'approved',
    true,
    true,
    'default_set_beginner',
    jsonb_build_array(
      jsonb_build_object('id','step-1','title','Cleanser','iconCodePoint',58823,'order',0),
      jsonb_build_object('id','step-2','title','Toner','iconCodePoint',58823,'order',1),
      jsonb_build_object('id','step-3','title','Serum','iconCodePoint',58823,'order',2),
      jsonb_build_object('id','step-4','title','Moisturizer','iconCodePoint',58823,'order',3),
      jsonb_build_object('id','step-5','title','Sunscreen','iconCodePoint',58823,'order',4)
    ),
    '{}'::jsonb,
    'system'
  ),
  (
    'default_set_structured_skincare',
    'Structured Concern-Based Skincare',
    'skincare',
    1,
    1,
    'approved',
    true,
    true,
    'default_set_structured',
    jsonb_build_array(
      jsonb_build_object('id','step-1','title','Cleanser','iconCodePoint',58823,'order',0),
      jsonb_build_object('id','step-2','title','Exfoliate (optional)','iconCodePoint',58823,'order',1),
      jsonb_build_object('id','step-3','title','Treatment serum','iconCodePoint',58823,'order',2),
      jsonb_build_object('id','step-4','title','Moisturizer','iconCodePoint',58823,'order',3),
      jsonb_build_object('id','step-5','title','SPF','iconCodePoint',58823,'order',4)
    ),
    '{}'::jsonb,
    'system'
  ),
  (
    'default_set_beginner_workout',
    'Beginner Full-Body Split',
    'workout',
    1,
    1,
    'approved',
    true,
    true,
    'default_set_beginner',
    jsonb_build_array(
      jsonb_build_object('id','step-1','title','Warm-up','iconCodePoint',58728,'order',0),
      jsonb_build_object('id','step-2','title','Compound movement','iconCodePoint',58728,'order',1),
      jsonb_build_object('id','step-3','title','Accessory sets','iconCodePoint',58728,'order',2),
      jsonb_build_object('id','step-4','title','Cooldown stretch','iconCodePoint',58728,'order',3)
    ),
    '{}'::jsonb,
    'system'
  ),
  (
    'default_set_structured_workout',
    'Structured Muscle Group Split',
    'workout',
    1,
    1,
    'approved',
    true,
    true,
    'default_set_structured',
    jsonb_build_array(
      jsonb_build_object('id','step-1','title','Primary muscle focus','iconCodePoint',58728,'order',0),
      jsonb_build_object('id','step-2','title','Secondary muscle focus','iconCodePoint',58728,'order',1),
      jsonb_build_object('id','step-3','title','Core finisher','iconCodePoint',58728,'order',2),
      jsonb_build_object('id','step-4','title','Mobility work','iconCodePoint',58728,'order',3)
    ),
    '{}'::jsonb,
    'system'
  ),
  (
    'default_set_beginner_meal_prep',
    'Beginner Weekly Meal Prep',
    'meal_prep',
    1,
    1,
    'approved',
    true,
    true,
    'default_set_beginner',
    jsonb_build_array(
      jsonb_build_object('id','step-1','title','Pick 3 meals','iconCodePoint',58134,'order',0),
      jsonb_build_object('id','step-2','title','Prepare grocery list','iconCodePoint',58134,'order',1),
      jsonb_build_object('id','step-3','title','Batch cook','iconCodePoint',58134,'order',2),
      jsonb_build_object('id','step-4','title','Portion and store','iconCodePoint',58134,'order',3)
    ),
    '{}'::jsonb,
    'system'
  ),
  (
    'default_set_structured_meal_prep',
    'Structured Batch + Leftovers Plan',
    'meal_prep',
    1,
    1,
    'approved',
    true,
    true,
    'default_set_structured',
    jsonb_build_array(
      jsonb_build_object('id','step-1','title','Plan macros for week','iconCodePoint',58134,'order',0),
      jsonb_build_object('id','step-2','title','Shop by category','iconCodePoint',58134,'order',1),
      jsonb_build_object('id','step-3','title','Cook proteins in batches','iconCodePoint',58134,'order',2),
      jsonb_build_object('id','step-4','title','Prep carbs and vegetables','iconCodePoint',58134,'order',3),
      jsonb_build_object('id','step-5','title','Label and refrigerate','iconCodePoint',58134,'order',4)
    ),
    '{}'::jsonb,
    'system'
  ),
  (
    'default_set_beginner_recipe',
    'Beginner Recipe Workflow',
    'recipe',
    1,
    1,
    'approved',
    true,
    true,
    'default_set_beginner',
    jsonb_build_array(
      jsonb_build_object('id','step-1','title','List ingredients','iconCodePoint',58134,'order',0),
      jsonb_build_object('id','step-2','title','Prep ingredients','iconCodePoint',58134,'order',1),
      jsonb_build_object('id','step-3','title','Cook in sequence','iconCodePoint',58134,'order',2),
      jsonb_build_object('id','step-4','title','Taste and adjust','iconCodePoint',58134,'order',3)
    ),
    '{}'::jsonb,
    'system'
  ),
  (
    'default_set_structured_recipe',
    'Structured Method-Varied Recipe',
    'recipe',
    1,
    1,
    'approved',
    true,
    true,
    'default_set_structured',
    jsonb_build_array(
      jsonb_build_object('id','step-1','title','Mise en place','iconCodePoint',58134,'order',0),
      jsonb_build_object('id','step-2','title','Primary method (air fryer/steam/etc)','iconCodePoint',58134,'order',1),
      jsonb_build_object('id','step-3','title','Secondary finish method','iconCodePoint',58134,'order',2),
      jsonb_build_object('id','step-4','title','Plate and note tweaks','iconCodePoint',58134,'order',3)
    ),
    '{}'::jsonb,
    'system'
  )
on conflict (id) do update
set
  name = excluded.name,
  category = excluded.category,
  schema_version = excluded.schema_version,
  template_version = excluded.template_version,
  status = excluded.status,
  is_public = excluded.is_public,
  is_official = excluded.is_official,
  set_key = excluded.set_key,
  steps_json = excluded.steps_json,
  metadata_json = excluded.metadata_json,
  updated_at = now();

