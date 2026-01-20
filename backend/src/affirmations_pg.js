import { withClient } from "./db.js";
import { randomId } from "./crypto.js";

/**
 * Get all affirmations for a user, optionally filtered by category
 */
export async function getAffirmationsPg(canvaUserId, category = null) {
  return await withClient(async (c) => {
    let query = "select affirmation_id, category, text, is_pinned, is_custom, created_at, updated_at from dv_affirmations where canva_user_id = $1";
    const params = [canvaUserId];
    
    if (category !== null && category !== undefined) {
      query += " and (category = $2 or category is null)";
      params.push(category);
    }
    
    query += " order by is_pinned desc, created_at desc";
    
    const r = await c.query(query, params);
    return r.rows.map((row) => ({
      id: row.affirmation_id,
      category: row.category ?? null,
      text: row.text,
      isPinned: row.is_pinned ?? false,
      isCustom: row.is_custom ?? true,
      createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null,
      updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null,
    }));
  });
}

/**
 * Get all affirmations for a user
 */
export async function getAllAffirmationsPg(canvaUserId) {
  return await getAffirmationsPg(canvaUserId, null);
}

/**
 * Create or update an affirmation
 */
export async function upsertAffirmationPg(canvaUserId, affirmation) {
  return await withClient(async (c) => {
    const affirmationId = affirmation.id || randomId();
    await c.query(
      `insert into dv_affirmations (canva_user_id, affirmation_id, category, text, is_pinned, is_custom)
       values ($1, $2, $3, $4, $5, $6)
       on conflict (canva_user_id, affirmation_id) do update set
         category = excluded.category,
         text = excluded.text,
         is_pinned = excluded.is_pinned,
         is_custom = excluded.is_custom,
         updated_at = now()`,
      [
        canvaUserId,
        affirmationId,
        affirmation.category ?? null,
        affirmation.text,
        affirmation.isPinned ?? false,
        affirmation.isCustom ?? true,
      ],
    );
    return affirmationId;
  });
}

/**
 * Delete an affirmation
 */
export async function deleteAffirmationPg(canvaUserId, affirmationId) {
  return await withClient(async (c) => {
    const r = await c.query(
      "delete from dv_affirmations where canva_user_id = $1 and affirmation_id = $2",
      [canvaUserId, affirmationId],
    );
    return r.rowCount > 0;
  });
}

/**
 * Pin or unpin an affirmation
 */
export async function pinAffirmationPg(canvaUserId, affirmationId, isPinned) {
  return await withClient(async (c) => {
    const r = await c.query(
      `update dv_affirmations 
       set is_pinned = $3, updated_at = now()
       where canva_user_id = $1 and affirmation_id = $2`,
      [canvaUserId, affirmationId, isPinned ?? false],
    );
    return r.rowCount > 0;
  });
}
