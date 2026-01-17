import { withClient } from "./db.js";

export async function getPkceStatePg(state) {
  return await withClient(async (c) => {
    const r = await c.query("select record from dv_pkce_states where state = $1", [state]);
    return r.rowCount ? r.rows[0].record : null;
  });
}

export async function putPkceStatePg(state, record) {
  return await withClient(async (c) => {
    await c.query(
      "insert into dv_pkce_states (state, record) values ($1, $2) on conflict (state) do update set record = excluded.record, created_at = now()",
      [state, record],
    );
  });
}

export async function deletePkceStatePg(state) {
  return await withClient(async (c) => {
    await c.query("delete from dv_pkce_states where state = $1", [state]);
  });
}

export async function getUserRecordPg(canvaUserId) {
  return await withClient(async (c) => {
    const r = await c.query("select * from dv_users where canva_user_id = $1", [canvaUserId]);
    if (!r.rowCount) return null;
    const row = r.rows[0];
    const guestExpiresAtMs =
      row.guest_expires_at != null ? new Date(row.guest_expires_at).getTime() : null;
    return {
      canvaUserId: row.canva_user_id,
      teamId: row.team_id,
      dvToken: row.dv_token,
      isGuest: Boolean(row.is_guest),
      guestExpiresAtMs,
      canva: {
        access_token: row.canva_access_token,
        refresh_token: row.canva_refresh_token,
        expires_in: row.canva_expires_in,
        token_type: row.canva_token_type,
        obtained_at: row.canva_obtained_at,
        scope: row.canva_scope,
      },
      habits: row.habits ?? [],
      packages: row.packages ?? [],
    };
  });
}

export async function putUserRecordPg(canvaUserId, record) {
  return await withClient(async (c) => {
    const isGuest = Boolean(record?.isGuest);
    const guestExpiresAtMs =
      typeof record?.guestExpiresAtMs === "number" ? record.guestExpiresAtMs : null;
    const guestExpiresAt = guestExpiresAtMs != null ? new Date(guestExpiresAtMs) : null;
    await c.query(
      `insert into dv_users (
        canva_user_id, team_id, dv_token,
        is_guest, guest_expires_at,
        canva_access_token, canva_refresh_token, canva_expires_in, canva_token_type, canva_obtained_at, canva_scope,
        habits, packages
      ) values (
        $1,$2,$3,
        $4,$5,
        $6,$7,$8,$9,$10,$11,
        $12,$13
      )
      on conflict (canva_user_id) do update set
        team_id = excluded.team_id,
        dv_token = excluded.dv_token,
        is_guest = excluded.is_guest,
        guest_expires_at = excluded.guest_expires_at,
        canva_access_token = excluded.canva_access_token,
        canva_refresh_token = excluded.canva_refresh_token,
        canva_expires_in = excluded.canva_expires_in,
        canva_token_type = excluded.canva_token_type,
        canva_obtained_at = excluded.canva_obtained_at,
        canva_scope = excluded.canva_scope,
        habits = excluded.habits,
        packages = excluded.packages,
        updated_at = now()`,
      [
        canvaUserId,
        record?.teamId ?? null,
        record?.dvToken,
        isGuest,
        guestExpiresAt,
        record?.canva?.access_token ?? null,
        record?.canva?.refresh_token ?? null,
        record?.canva?.expires_in ?? null,
        record?.canva?.token_type ?? null,
        record?.canva?.obtained_at ?? null,
        record?.canva?.scope ?? null,
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
      canvaUserId: row.canva_user_id,
      teamId: row.team_id,
      dvToken: row.dv_token,
      isGuest: Boolean(row.is_guest),
      guestExpiresAtMs,
      canva: {
        access_token: row.canva_access_token,
        refresh_token: row.canva_refresh_token,
        expires_in: row.canva_expires_in,
        token_type: row.canva_token_type,
        obtained_at: row.canva_obtained_at,
        scope: row.canva_scope,
      },
      habits: row.habits ?? [],
      packages: row.packages ?? [],
    };
  });
}

export async function putOauthPollTokenPg(pollToken, { dvToken, canvaUserId }) {
  return await withClient(async (c) => {
    await c.query(
      `insert into dv_oauth_poll_tokens (poll_token, dv_token, canva_user_id)
       values ($1, $2, $3)
       on conflict (poll_token) do update set
         dv_token = excluded.dv_token,
         canva_user_id = excluded.canva_user_id,
         updated_at = now()`,
      [pollToken, dvToken ?? null, canvaUserId ?? null],
    );
  });
}

export async function getOauthPollTokenPg(pollToken) {
  return await withClient(async (c) => {
    const r = await c.query(
      "select poll_token, dv_token, canva_user_id, updated_at from dv_oauth_poll_tokens where poll_token = $1",
      [pollToken],
    );
    if (!r.rowCount) return null;
    const row = r.rows[0];
    return {
      pollToken: row.poll_token,
      dvToken: row.dv_token ?? null,
      canvaUserId: row.canva_user_id ?? null,
      updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null,
    };
  });
}
