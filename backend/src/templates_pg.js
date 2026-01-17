import { withClient } from "./db.js";

export async function insertTemplateImagePg({
  id,
  createdBy,
  contentType,
  bytes,
}) {
  return await withClient(async (c) => {
    await c.query(
      `insert into dv_template_images (id, created_by, content_type, bytes)
       values ($1, $2, $3, $4)
       on conflict (id) do update set
         created_by = excluded.created_by,
         content_type = excluded.content_type,
         bytes = excluded.bytes,
         updated_at = now()`,
      [id, createdBy, contentType, bytes],
    );
    return { id };
  });
}

export async function getTemplateImagePg(id) {
  return await withClient(async (c) => {
    const r = await c.query("select id, content_type, bytes from dv_template_images where id = $1", [id]);
    if (!r.rowCount) return null;
    return {
      id: r.rows[0].id,
      contentType: r.rows[0].content_type ?? "application/octet-stream",
      bytes: r.rows[0].bytes,
    };
  });
}

export async function listTemplatesPg() {
  return await withClient(async (c) => {
    const r = await c.query(
      `select id, name, kind, preview_image_id, updated_at
       from dv_board_templates
       order by updated_at desc`,
    );
    return r.rows.map((row) => ({
      id: row.id,
      name: row.name,
      kind: row.kind,
      previewImageId: row.preview_image_id ?? null,
      updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null,
    }));
  });
}

export async function getTemplatePg(id) {
  return await withClient(async (c) => {
    const r = await c.query(
      `select id, name, kind, template_json, preview_image_id, created_by, updated_at
       from dv_board_templates
       where id = $1`,
      [id],
    );
    if (!r.rowCount) return null;
    const row = r.rows[0];
    return {
      id: row.id,
      name: row.name,
      kind: row.kind,
      templateJson: row.template_json ?? {},
      previewImageId: row.preview_image_id ?? null,
      createdBy: row.created_by ?? null,
      updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null,
    };
  });
}

export async function upsertTemplatePg({
  id,
  name,
  kind,
  templateJson,
  previewImageId,
  createdBy,
}) {
  return await withClient(async (c) => {
    await c.query(
      `insert into dv_board_templates (id, name, kind, template_json, preview_image_id, created_by)
       values ($1, $2, $3, $4::jsonb, $5, $6)
       on conflict (id) do update set
         name = excluded.name,
         kind = excluded.kind,
         template_json = excluded.template_json,
         preview_image_id = excluded.preview_image_id,
         updated_at = now()`,
      [id, name, kind, JSON.stringify(templateJson ?? {}), previewImageId ?? null, createdBy],
    );
    return { id };
  });
}

export async function deleteTemplatePg(id) {
  return await withClient(async (c) => {
    const r = await c.query("delete from dv_board_templates where id = $1", [id]);
    return { deleted: r.rowCount > 0 };
  });
}

