import { withClient } from "./db.js";

const DEFAULTS_ID = "wizard_defaults_v1";

export async function getWizardDefaultsPg() {
  return await withClient(async (c) => {
    const r = await c.query("select defaults_json, updated_at from dv_wizard_defaults where id = $1", [
      DEFAULTS_ID,
    ]);
    if (!r.rowCount) return null;
    return {
      defaults: r.rows[0].defaults_json ?? null,
      updatedAt: r.rows[0].updated_at?.toISOString?.() ?? r.rows[0].updated_at ?? null,
    };
  });
}

export async function putWizardDefaultsPg({ defaults }) {
  return await withClient(async (c) => {
    await c.query(
      `insert into dv_wizard_defaults (id, defaults_json)
       values ($1, $2)
       on conflict (id) do update set
         defaults_json = excluded.defaults_json,
         updated_at = now()`,
      [DEFAULTS_ID, JSON.stringify(defaults ?? {})],
    );
  });
}

export async function getWizardRecommendationsPg({ coreValueId, categoryKey }) {
  return await withClient(async (c) => {
    const r = await c.query(
      `select core_value_id, category_key, category_label, recommendations_json, source, created_by, updated_at
       from dv_wizard_recommendations
       where core_value_id = $1 and category_key = $2`,
      [coreValueId, categoryKey],
    );
    if (!r.rowCount) return null;
    const row = r.rows[0];
    return {
      coreValueId: row.core_value_id,
      categoryKey: row.category_key,
      categoryLabel: row.category_label,
      recommendations: row.recommendations_json ?? null,
      source: row.source ?? null,
      createdBy: row.created_by ?? null,
      updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null,
    };
  });
}

export async function upsertWizardRecommendationsPg({
  coreValueId,
  categoryKey,
  categoryLabel,
  recommendations,
  source,
  createdBy,
}) {
  return await withClient(async (c) => {
    await c.query(
      `insert into dv_wizard_recommendations (
         core_value_id, category_key, category_label, recommendations_json, source, created_by
       ) values ($1,$2,$3,$4,$5,$6)
       on conflict (core_value_id, category_key) do update set
         category_label = excluded.category_label,
         recommendations_json = excluded.recommendations_json,
         source = excluded.source,
         created_by = excluded.created_by,
         updated_at = now()`,
      [
        coreValueId,
        categoryKey,
        categoryLabel,
        JSON.stringify(recommendations ?? {}),
        source ?? null,
        createdBy ?? null,
      ],
    );
  });
}

