import { withClient } from "./db.js";

const ALLOWED_KINDS = new Set(["contact", "issue"]);
const ALLOWED_STATUSES = new Set(["open", "in_progress", "resolved"]);

function normalizeKind(kind) {
  const key = String(kind ?? "")
    .trim()
    .toLowerCase();
  return ALLOWED_KINDS.has(key) ? key : "contact";
}

function normalizeStatus(status) {
  const key = String(status ?? "")
    .trim()
    .toLowerCase();
  return ALLOWED_STATUSES.has(key) ? key : "open";
}

function mapMessageRow(r) {
  return {
    id: Number(r.id),
    name: String(r.name ?? ""),
    email: String(r.email ?? ""),
    subject: String(r.subject ?? ""),
    message: String(r.message ?? ""),
    kind: normalizeKind(r.kind),
    status: normalizeStatus(r.status),
    userId: r.user_id ? String(r.user_id) : null,
    createdAt: r.created_at ? new Date(r.created_at).toISOString() : null,
  };
}

export async function insertContactMessagePg({ name, email, subject = "", message, kind = "contact", userId = null }) {
  return await withClient(async (c) => {
    const kindKey = normalizeKind(kind);
    const nextStatus = kindKey === "issue" ? "open" : "resolved";
    await c.query(
      `insert into dv_contact_messages (name, email, subject, message, kind, status, user_id)
       values ($1, $2, $3, $4, $5, $6, $7)`,
      [name, email, subject, message, kindKey, nextStatus, userId],
    );
    return { ok: true };
  });
}

export async function listContactMessagesPg({ limit = 100 } = {}) {
  return await withClient(async (c) => {
    const safeLimit = Number.isFinite(limit) ? Math.max(1, Math.min(Number(limit), 500)) : 100;
    const { rows } = await c.query(
      `select id, name, email, subject, message, kind, status, user_id, created_at
       from dv_contact_messages
       order by created_at desc
       limit $1`,
      [safeLimit],
    );
    return rows.map(mapMessageRow);
  });
}

export async function listMyIssueReportsPg({ userId, limit = 100 } = {}) {
  return await withClient(async (c) => {
    const uid = String(userId ?? "").trim();
    if (!uid) return [];
    const safeLimit = Number.isFinite(limit) ? Math.max(1, Math.min(Number(limit), 500)) : 100;
    const { rows } = await c.query(
      `select id, name, email, subject, message, kind, status, user_id, created_at
       from dv_contact_messages
       where kind = 'issue' and user_id = $1
       order by created_at desc
       limit $2`,
      [uid, safeLimit],
    );
    return rows.map(mapMessageRow);
  });
}

export async function updateContactMessageStatusPg({ id, status }) {
  return await withClient(async (c) => {
    const safeId = Number(id);
    if (!Number.isFinite(safeId) || safeId <= 0) return { ok: false, error: "invalid_id" };
    const nextStatus = normalizeStatus(status);
    const { rowCount } = await c.query(
      `update dv_contact_messages
       set status = $1
       where id = $2 and kind = 'issue'`,
      [nextStatus, safeId],
    );
    if (!rowCount) return { ok: false, error: "not_found" };
    return { ok: true };
  });
}
