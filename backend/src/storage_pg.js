import { withClient } from "./db.js";

export async function getUserRecordPg(userId) {
  return await withClient(async (c) => {
    const r = await c.query("select * from dv_users where user_id = $1", [userId]);
    if (!r.rowCount) return null;
    const row = r.rows[0];
    const guestExpiresAtMs =
      row.guest_expires_at != null ? new Date(row.guest_expires_at).getTime() : null;
    return {
      userId: row.user_id,
      dvToken: row.dv_token,
      isGuest: Boolean(row.is_guest),
      guestExpiresAtMs,
      habits: row.habits ?? [],
      packages: row.packages ?? [],
    };
  });
}

export async function putUserRecordPg(userId, record) {
  return await withClient(async (c) => {
    const isGuest = Boolean(record?.isGuest);
    const guestExpiresAtMs =
      typeof record?.guestExpiresAtMs === "number" ? record.guestExpiresAtMs : null;
    const guestExpiresAt = guestExpiresAtMs != null ? new Date(guestExpiresAtMs) : null;
    await c.query(
      `insert into dv_users (
        user_id, dv_token,
        is_guest, guest_expires_at,
        habits, packages
      ) values (
        $1,$2,
        $3,$4,
        $5,$6
      )
      on conflict (user_id) do update set
        dv_token = excluded.dv_token,
        is_guest = excluded.is_guest,
        guest_expires_at = excluded.guest_expires_at,
        habits = excluded.habits,
        packages = excluded.packages,
        updated_at = now()`,
      [
        userId,
        record?.dvToken,
        isGuest,
        guestExpiresAt,
        JSON.stringify(record?.habits ?? []),
        JSON.stringify(record?.packages ?? []),
      ],
    );
  });
}

export async function findUserByDvTokenPg(dvToken) {
  return await withClient(async (c) => {
    const r = await c.query("select * from dv_users where dv_token = $1", [dvToken]);
    if (!r.rowCount) return null;
    const row = r.rows[0];
    const guestExpiresAtMs =
      row.guest_expires_at != null ? new Date(row.guest_expires_at).getTime() : null;
    return {
      userId: row.user_id,
      dvToken: row.dv_token,
      isGuest: Boolean(row.is_guest),
      guestExpiresAtMs,
      habits: row.habits ?? [],
      packages: row.packages ?? [],
    };
  });
}
