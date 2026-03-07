import { withClient } from "./db.js";

export async function insertContactMessagePg({ name, email, message }) {
  return await withClient(async (c) => {
    await c.query(
      `insert into dv_contact_messages (name, email, message)
       values ($1, $2, $3)`,
      [name, email, message],
    );
    return { ok: true };
  });
}

export async function listContactMessagesPg({ limit = 100 } = {}) {
  return await withClient(async (c) => {
    const safeLimit = Number.isFinite(limit) ? Math.max(1, Math.min(Number(limit), 500)) : 100;
    const { rows } = await c.query(
      `select id, name, email, message, created_at
       from dv_contact_messages
       order by created_at desc
       limit $1`,
      [safeLimit],
    );
    return rows.map((r) => ({
      id: Number(r.id),
      name: String(r.name ?? ""),
      email: String(r.email ?? ""),
      message: String(r.message ?? ""),
      createdAt: r.created_at ? new Date(r.created_at).toISOString() : null,
    }));
  });
}
