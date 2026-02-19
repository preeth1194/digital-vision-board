import { withClient } from "./db.js";

/**
 * Look up a gift code by its code string.
 * Returns the code record or null if not found.
 */
export async function getGiftCodePg(code) {
  return await withClient(async (c) => {
    const r = await c.query(
      "SELECT code, plan_id, duration_days, max_uses, used_count, active FROM dv_gift_codes WHERE code = $1",
      [code],
    );
    if (!r.rowCount) return null;
    const row = r.rows[0];
    return {
      code: row.code,
      planId: row.plan_id,
      durationDays: row.duration_days,
      maxUses: row.max_uses,
      usedCount: row.used_count,
      active: row.active,
    };
  });
}

/**
 * Redeem a gift code for a user. Runs inside a transaction to prevent races.
 * Returns { ok: true, planId } on success, or { ok: false, error } on failure.
 */
export async function redeemGiftCodePg(code, canvaUserId) {
  return await withClient(async (c) => {
    await c.query("BEGIN");
    try {
      // Lock the gift code row
      const r = await c.query(
        "SELECT code, plan_id, duration_days, max_uses, used_count, active FROM dv_gift_codes WHERE code = $1 FOR UPDATE",
        [code],
      );
      if (!r.rowCount) {
        await c.query("ROLLBACK");
        return { ok: false, error: "invalid_code" };
      }

      const row = r.rows[0];
      if (!row.active) {
        await c.query("ROLLBACK");
        return { ok: false, error: "code_inactive" };
      }
      if (row.used_count >= row.max_uses) {
        await c.query("ROLLBACK");
        return { ok: false, error: "code_exhausted" };
      }

      // Check if user already redeemed this code
      const dup = await c.query(
        "SELECT 1 FROM dv_gift_code_redemptions WHERE code = $1 AND canva_user_id = $2",
        [code, canvaUserId],
      );
      if (dup.rowCount) {
        await c.query("ROLLBACK");
        return { ok: false, error: "already_redeemed" };
      }

      // Increment used_count
      await c.query(
        "UPDATE dv_gift_codes SET used_count = used_count + 1 WHERE code = $1",
        [code],
      );

      // Log the redemption
      await c.query(
        "INSERT INTO dv_gift_code_redemptions (code, canva_user_id) VALUES ($1, $2)",
        [code, canvaUserId],
      );

      // Activate subscription in user settings
      await c.query(
        `INSERT INTO dv_user_settings (canva_user_id, subscription_plan_id, subscription_active, subscription_updated_at, subscription_source)
         VALUES ($1, $2, true, now(), 'gift_code')
         ON CONFLICT (canva_user_id) DO UPDATE
           SET subscription_plan_id = $2,
               subscription_active = true,
               subscription_updated_at = now(),
               subscription_source = 'gift_code'`,
        [canvaUserId, row.plan_id],
      );

      await c.query("COMMIT");
      return { ok: true, planId: row.plan_id };
    } catch (e) {
      await c.query("ROLLBACK");
      throw e;
    }
  });
}
