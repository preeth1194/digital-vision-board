import { withClient } from "./db.js";

export async function listStockCategoryImagesPg({ coreValueId, categoryKey, limit = 12 }) {
  return await withClient(async (c) => {
    const lim = Math.max(1, Math.min(50, Number.isFinite(Number(limit)) ? Math.trunc(Number(limit)) : 12));
    const r = await c.query(
      `select id, core_value_id, category_key, category_label, pexels_photo_id, image_url, alt, photographer, updated_at
       from dv_stock_category_images
       where core_value_id = $1 and category_key = $2
       order by updated_at desc
       limit $3`,
      [coreValueId, categoryKey, lim],
    );
    return r.rows.map((row) => ({
      id: row.id,
      coreValueId: row.core_value_id,
      categoryKey: row.category_key,
      categoryLabel: row.category_label,
      pexelsPhotoId: row.pexels_photo_id ?? null,
      imageUrl: row.image_url,
      alt: row.alt ?? "",
      photographer: row.photographer ?? "",
      updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null,
    }));
  });
}

export async function upsertStockCategoryImagePg({
  id,
  coreValueId,
  categoryKey,
  categoryLabel,
  pexelsPhotoId,
  query,
  imageUrl,
  alt,
  photographer,
}) {
  return await withClient(async (c) => {
    await c.query(
      `insert into dv_stock_category_images (
         id, core_value_id, category_key, category_label, pexels_photo_id, query, image_url, alt, photographer
       ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9)
       on conflict (core_value_id, category_key, pexels_photo_id) do update set
         category_label = excluded.category_label,
         query = excluded.query,
         image_url = excluded.image_url,
         alt = excluded.alt,
         photographer = excluded.photographer,
         updated_at = now()`,
      [
        id,
        coreValueId,
        categoryKey,
        categoryLabel,
        (pexelsPhotoId == null ? null : Number(pexelsPhotoId)),
        query ?? null,
        imageUrl,
        alt ?? null,
        photographer ?? null,
      ],
    );
    return { id };
  });
}

