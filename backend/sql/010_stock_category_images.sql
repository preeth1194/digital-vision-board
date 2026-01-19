-- Stock category images (Pexels URLs cached in DB), v1

create table if not exists dv_stock_category_images (
  id text primary key,
  core_value_id text not null,
  category_key text not null,
  category_label text not null,
  pexels_photo_id bigint,
  query text,
  image_url text not null,
  alt text,
  photographer text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists dv_stock_category_images_unique_idx
  on dv_stock_category_images (core_value_id, category_key, pexels_photo_id);

create index if not exists dv_stock_category_images_lookup_idx
  on dv_stock_category_images (core_value_id, category_key, updated_at desc);

