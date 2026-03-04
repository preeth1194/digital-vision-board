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

function mapActionTemplateRow(row) {
  return {
    id: row.id,
    name: row.name,
    category: row.category,
    schemaVersion: row.schema_version ?? 1,
    templateVersion: row.template_version ?? 1,
    status: row.status,
    isPublic: row.is_public === true,
    isOfficial: row.is_official === true,
    setKey: row.set_key ?? null,
    steps: Array.isArray(row.steps_json) ? row.steps_json : [],
    metadata: row.metadata_json ?? {},
    createdByUserId: row.created_by ?? null,
    reviewedBy: row.reviewed_by ?? null,
    reviewedAt: row.reviewed_at?.toISOString?.() ?? row.reviewed_at ?? null,
    reviewNotes: row.review_notes ?? null,
    updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null,
  };
}

export async function listApprovedActionTemplatesPg({ category }) {
  return await withClient(async (c) => {
    const hasCategory = typeof category === "string" && category.trim().length > 0;
    const r = hasCategory
      ? await c.query(
          `select id, name, category, schema_version, template_version, status, is_public,
                  is_official, set_key, steps_json, metadata_json, created_by, reviewed_by,
                  reviewed_at, review_notes, updated_at
           from dv_action_templates
           where status = 'approved' and is_public = true and category = $1
           order by is_official desc, updated_at desc`,
          [category.trim()],
        )
      : await c.query(
          `select id, name, category, schema_version, template_version, status, is_public,
                  is_official, set_key, steps_json, metadata_json, created_by, reviewed_by,
                  reviewed_at, review_notes, updated_at
           from dv_action_templates
           where status = 'approved' and is_public = true
           order by is_official desc, updated_at desc`,
        );
    return r.rows.map(mapActionTemplateRow);
  });
}

export async function submitActionTemplateDraftPg({
  id,
  name,
  category,
  schemaVersion,
  templateVersion,
  steps,
  metadata,
  createdBy,
}) {
  return await withClient(async (c) => {
    await c.query(
      `insert into dv_action_templates (
        id, name, category, schema_version, template_version, status, is_public,
        is_official, set_key, steps_json, metadata_json, created_by
      ) values ($1, $2, $3, $4, $5, 'submitted', false, false, null, $6::jsonb, $7::jsonb, $8)
      on conflict (id) do update set
        name = excluded.name,
        category = excluded.category,
        schema_version = excluded.schema_version,
        template_version = excluded.template_version,
        status = 'submitted',
        is_public = false,
        is_official = false,
        set_key = null,
        steps_json = excluded.steps_json,
        metadata_json = excluded.metadata_json,
        updated_at = now()`,
      [
        id,
        name,
        category,
        schemaVersion ?? 1,
        templateVersion ?? 1,
        JSON.stringify(steps ?? []),
        JSON.stringify(metadata ?? {}),
        createdBy,
      ],
    );
    const r = await c.query(
      `select id, name, category, schema_version, template_version, status, is_public,
              is_official, set_key, steps_json, metadata_json, created_by, reviewed_by,
              reviewed_at, review_notes, updated_at
       from dv_action_templates
       where id = $1`,
      [id],
    );
    return r.rowCount ? mapActionTemplateRow(r.rows[0]) : null;
  });
}

export async function reviewActionTemplatePg({
  id,
  status,
  reviewedBy,
  reviewNotes,
}) {
  return await withClient(async (c) => {
    const approved = status === "approved";
    const r = await c.query(
      `update dv_action_templates
       set status = $2,
           is_public = $3,
           reviewed_by = $4,
           reviewed_at = now(),
           review_notes = $5,
           updated_at = now()
       where id = $1
       returning id, name, category, schema_version, template_version, status, is_public,
                 is_official, set_key, steps_json, metadata_json, created_by, reviewed_by,
                 reviewed_at, review_notes, updated_at`,
      [id, status, approved, reviewedBy, reviewNotes ?? null],
    );
    return r.rowCount ? mapActionTemplateRow(r.rows[0]) : null;
  });
}

