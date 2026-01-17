import "dotenv/config";
import express from "express";
import cors from "cors";
import multer from "multer";
import sharp from "sharp";

import { randomId, sha256Base64Url } from "./crypto.js";
import {
  canvaAuthorizeUrl,
  createExportJob,
  exchangeAuthorizationCode,
  getExportJob,
  getUsersMe,
  refreshAccessToken,
} from "./canva_connect.js";
import {
  deletePkceState,
  getOauthPollToken,
  getPkceState,
  getUserRecord,
  putOauthPollToken,
  putPkceState,
  putUserRecord,
} from "./storage.js";
import { requireAdmin, requireDvAuth } from "./auth.js";
import { ensureSchema } from "./migrate.js";
import { hasDatabase } from "./db.js";
import {
  applySyncPushPg,
  cleanupOldLogsPg,
  getRecentChecklistEventsPg,
  getRecentHabitCompletionsPg,
  getUserSettingsPg,
  listBoardsPg,
  putUserSettingsPg,
} from "./sync_pg.js";
import {
  deleteTemplatePg,
  getTemplateImagePg,
  getTemplatePg,
  insertTemplateImagePg,
  listTemplatesPg,
  upsertTemplatePg,
} from "./templates_pg.js";

const app = express();

// Ensure DB tables exist (idempotent).
await ensureSchema();

app.use(
  cors({
    origin: process.env.CORS_ORIGIN ?? "*",
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["content-type", "authorization"],
  }),
);
app.use(express.json({ limit: "2mb" }));

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 15 * 1024 * 1024 }, // 15MB
});

function templateImagePath(id) {
  return `/template-images/${encodeURIComponent(id)}`;
}

function ensureDbOr501(res) {
  if (hasDatabase()) return true;
  res.status(501).json({ error: "database_required" });
  return false;
}

app.get("/", (req, res) => {
  res
    .status(200)
    .type("text/plain")
    .send(
      [
        "Digital Vision Board backend is running.",
        "",
        "Useful endpoints:",
        "- GET /health",
        "- GET /auth/canva/start",
        "- GET /canva/connect (alias)",
      ].join("\n"),
    );
});

app.get("/health", (req, res) => res.json({ ok: true }));

/**
 * Guest auth (no Canva required).
 * Returns a backend-issued dvToken that expires in 10 days.
 *
 * Body (optional):
 * - home_timezone: IANA timezone string (e.g. "America/Los_Angeles")
 */
app.post("/auth/guest", async (req, res) => {
  try {
    const homeTimezone = typeof req.body?.home_timezone === "string" ? req.body.home_timezone : null;
    const now = Date.now();
    const expiresAtMs = now + 10 * 24 * 60 * 60 * 1000;
    const dvToken = randomId(24);
    const guestId = `guest_${randomId(16)}`;

    await putUserRecord(guestId, {
      canvaUserId: guestId,
      teamId: null,
      dvToken,
      isGuest: true,
      guestExpiresAtMs: expiresAtMs,
      canva: {
        access_token: null,
        refresh_token: null,
        expires_in: null,
        token_type: "Bearer",
        obtained_at: null,
        scope: null,
      },
      habits: [],
      packages: [],
    });

    if (hasDatabase() && homeTimezone) {
      await putUserSettingsPg(guestId, { homeTimezone });
    }

    res.json({
      ok: true,
      dvToken,
      expiresAt: new Date(expiresAtMs).toISOString(),
      home_timezone: homeTimezone,
    });
  } catch (e) {
    res.status(500).json({ error: "guest_auth_failed", message: String(e?.message ?? e) });
  }
});

/**
 * Canva OAuth start for sandboxed environments (no window.opener).
 * Returns an auth URL + a poll token that the client can poll for dvToken.
 */
app.get("/auth/canva/start_poll", async (req, res) => {
  const state = randomId(16);
  const codeVerifier = randomId(32);
  const codeChallenge = sha256Base64Url(codeVerifier);
  const pollToken = `poll_${randomId(16)}`;

  await putPkceState(state, { codeVerifier, createdAt: Date.now(), pollToken, returnTo: "", origin: "" });
  const url = canvaAuthorizeUrl({ state, codeChallenge });
  res.json({ ok: true, authUrl: url, pollToken });
});

/**
 * Poll for completion of a prior /auth/canva/start_poll flow.
 * Query:
 * - pollToken: string
 */
app.get("/auth/canva/poll", async (req, res) => {
  const pollToken = typeof req.query.pollToken === "string" ? req.query.pollToken : null;
  if (!pollToken) return res.status(400).json({ error: "missing_pollToken" });

  const rec = await getOauthPollToken(pollToken);
  if (!rec?.dvToken) return res.json({ ok: true, status: "pending" });

  res.json({
    ok: true,
    status: "completed",
    dvToken: rec.dvToken,
    canvaUserId: rec.canvaUserId ?? null,
  });
});

// Back-compat for the Canva panel (expected in canva-app-panel/README.md)
app.get("/canva/connect", async (req, res) => {
  const qs = new URLSearchParams();
  if (typeof req.query.returnTo === "string") qs.set("returnTo", req.query.returnTo);
  if (typeof req.query.origin === "string") qs.set("origin", req.query.origin);
  res.redirect(`/auth/canva/start?${qs.toString()}`);
});

/**
 * Start Canva OAuth in a popup window.
 * Query params:
 * - returnTo: where the popup should postMessage back to (string; optional)
 * - origin: expected opener origin for postMessage (string; optional)
 */
app.get("/auth/canva/start", async (req, res) => {
  const state = randomId(16);
  const codeVerifier = randomId(32);
  const codeChallenge = sha256Base64Url(codeVerifier);

  const returnTo = typeof req.query.returnTo === "string" ? req.query.returnTo : "";
  const origin = typeof req.query.origin === "string" ? req.query.origin : "";

  await putPkceState(state, { codeVerifier, createdAt: Date.now(), returnTo, origin });
  const url = canvaAuthorizeUrl({ state, codeChallenge });
  res.redirect(url);
});

/**
 * Canva OAuth callback.
 * Exchanges code for token, resolves canva user id, creates dvToken, stores record.
 * Responds with HTML that postMessage's { dvToken, canvaUserId } to window.opener.
 */
app.get("/auth/canva/callback", async (req, res) => {
  try {
    const code = typeof req.query.code === "string" ? req.query.code : null;
    const state = typeof req.query.state === "string" ? req.query.state : null;
    if (!code || !state) return res.status(400).send("Missing code/state");

    const st = await getPkceState(state);
    if (!st?.codeVerifier) return res.status(400).send("Invalid state");

    const token = await exchangeAuthorizationCode({ code, codeVerifier: st.codeVerifier });
    const me = await getUsersMe(token.access_token);
    const canvaUserId = me?.team_user?.user_id;
    if (!canvaUserId) return res.status(500).send("Could not resolve Canva user id");

    const existing = (await getUserRecord(canvaUserId)) ?? {};
    const dvToken = existing.dvToken ?? randomId(24);

    await putUserRecord(canvaUserId, {
      ...existing,
      canvaUserId,
      teamId: me?.team_user?.team_id ?? null,
      dvToken,
      canva: {
        access_token: token.access_token,
        refresh_token: token.refresh_token ?? null,
        expires_in: token.expires_in ?? null,
        token_type: token.token_type ?? "Bearer",
        obtained_at: Date.now(),
        scope: token.scope ?? null,
      },
      habits: Array.isArray(existing.habits) ? existing.habits : [],
      packages: Array.isArray(existing.packages) ? existing.packages : [],
    });

    if (st?.pollToken) {
      await putOauthPollToken(st.pollToken, { dvToken, canvaUserId });
    }

    await deletePkceState(state);

    // If a returnTo is supplied (e.g. deep-link back into Flutter), redirect there.
    // Example returnTo: dvb://oauth
    if (st.returnTo && typeof st.returnTo === "string" && st.returnTo.trim() !== "") {
      const url = new URL(st.returnTo);
      url.searchParams.set("dvToken", dvToken);
      url.searchParams.set("canvaUserId", canvaUserId);
      return res.redirect(url.toString());
    }

    if (st?.pollToken) {
      res.setHeader("content-type", "text/html; charset=utf-8");
      return res.send(`<!doctype html>
<html>
  <body>
    Connected. You can close this tab and return to Canva.
  </body>
</html>`);
    }

    const targetOrigin = st.origin && st.origin !== "" ? st.origin : "*";
    res.setHeader("content-type", "text/html; charset=utf-8");
    res.send(`<!doctype html>
<html>
  <body>
    <script>
      (function () {
        const payload = {
          type: "dv_canva_oauth_success",
          dvToken: ${JSON.stringify(dvToken)},
          canvaUserId: ${JSON.stringify(canvaUserId)}
        };
        try {
          if (window.opener && window.opener.postMessage) {
            window.opener.postMessage(payload, ${JSON.stringify(targetOrigin)});
          }
        } catch (e) {}
        window.close();
        document.body.innerText = "Connected. You can close this window.";
      })();
    </script>
  </body>
</html>`);
  } catch (e) {
    res.status(500).send(String(e?.message ?? e));
  }
});

// ---- Authenticated APIs (dvToken) ----
app.get("/habits", requireDvAuth(), async (req, res) => {
  res.json({ habits: req.dvUser.habits ?? [] });
});

// ---- Templates (user) ----
app.get("/templates", requireDvAuth(), async (req, res) => {
  if (!ensureDbOr501(res)) return;
  const list = await listTemplatesPg();
  res.json({
    templates: list.map((t) => ({
      id: t.id,
      name: t.name,
      kind: t.kind,
      previewImageUrl: t.previewImageId ? templateImagePath(t.previewImageId) : null,
      updatedAt: t.updatedAt ?? null,
    })),
  });
});

app.get("/templates/:id", requireDvAuth(), async (req, res) => {
  if (!ensureDbOr501(res)) return;
  const t = await getTemplatePg(req.params.id);
  if (!t) return res.status(404).json({ error: "template_not_found" });
  res.json({
    template: {
      id: t.id,
      name: t.name,
      kind: t.kind,
      templateJson: t.templateJson ?? {},
      previewImageUrl: t.previewImageId ? templateImagePath(t.previewImageId) : null,
      updatedAt: t.updatedAt ?? null,
    },
  });
});

// Public image serving (Image.network can’t attach headers)
app.get("/template-images/:id", async (req, res) => {
  if (!ensureDbOr501(res)) return;
  const found = await getTemplateImagePg(req.params.id);
  if (!found) return res.status(404).send("Not found");
  res.setHeader("content-type", found.contentType ?? "application/octet-stream");
  res.setHeader("cache-control", "public, max-age=31536000, immutable");
  res.status(200).send(found.bytes);
});

// ---- Templates (admin) ----
app.get("/admin/templates", requireAdmin(), async (req, res) => {
  if (!ensureDbOr501(res)) return;
  const list = await listTemplatesPg();
  res.json({
    templates: list.map((t) => ({
      id: t.id,
      name: t.name,
      kind: t.kind,
      previewImageUrl: t.previewImageId ? templateImagePath(t.previewImageId) : null,
      updatedAt: t.updatedAt ?? null,
    })),
  });
});

app.post("/admin/template-images", requireAdmin(), upload.single("file"), async (req, res) => {
  if (!ensureDbOr501(res)) return;
  const f = req.file;
  if (!f || !f.buffer) return res.status(400).json({ error: "missing_file" });
  const id = `timg_${randomId(16)}`;
  const createdBy = req.dvUser.canvaUserId;
  await insertTemplateImagePg({
    id,
    createdBy,
    contentType: f.mimetype || "application/octet-stream",
    bytes: f.buffer,
  });
  res.json({ ok: true, imageId: id, url: templateImagePath(id) });
});

app.post("/admin/templates", requireAdmin(), async (req, res) => {
  if (!ensureDbOr501(res)) return;
  const name = typeof req.body?.name === "string" ? req.body.name.trim() : "";
  const kind = typeof req.body?.kind === "string" ? req.body.kind.trim() : "";
  const templateJson = typeof req.body?.templateJson === "object" && req.body.templateJson ? req.body.templateJson : {};
  const previewImageId = typeof req.body?.previewImageId === "string" ? req.body.previewImageId : null;
  if (!name) return res.status(400).json({ error: "missing_name" });
  if (kind !== "goal_canvas" && kind !== "grid") return res.status(400).json({ error: "invalid_kind" });
  const id = `tpl_${randomId(16)}`;
  await upsertTemplatePg({
    id,
    name,
    kind,
    templateJson,
    previewImageId,
    createdBy: req.dvUser.canvaUserId,
  });
  res.json({ ok: true, id });
});

app.put("/admin/templates/:id", requireAdmin(), async (req, res) => {
  if (!ensureDbOr501(res)) return;
  const id = req.params.id;
  const name = typeof req.body?.name === "string" ? req.body.name.trim() : "";
  const kind = typeof req.body?.kind === "string" ? req.body.kind.trim() : "";
  const templateJson = typeof req.body?.templateJson === "object" && req.body.templateJson ? req.body.templateJson : {};
  const previewImageId = typeof req.body?.previewImageId === "string" ? req.body.previewImageId : null;
  if (!name) return res.status(400).json({ error: "missing_name" });
  if (kind !== "goal_canvas" && kind !== "grid") return res.status(400).json({ error: "invalid_kind" });
  await upsertTemplatePg({
    id,
    name,
    kind,
    templateJson,
    previewImageId,
    createdBy: req.dvUser.canvaUserId,
  });
  res.json({ ok: true, id });
});

app.delete("/admin/templates/:id", requireAdmin(), async (req, res) => {
  if (!ensureDbOr501(res)) return;
  const id = req.params.id;
  const result = await deleteTemplatePg(id);
  res.json({ ok: true, deleted: result.deleted });
});

function decodeJwtPayload(jwt) {
  // Minimal/dev-friendly decoder (no signature verification).
  // TODO: verify with Canva JWKS + expected audience when hardening.
  try {
    const parts = String(jwt).split(".");
    if (parts.length < 2) return null;
    const b64 = parts[1].replaceAll("-", "+").replaceAll("_", "/");
    const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
    const json = Buffer.from(padded, "base64").toString("utf-8");
    return JSON.parse(json);
  } catch {
    return null;
  }
}

async function downloadBytes(url) {
  const res = await fetch(url);
  if (res.status < 200 || res.status >= 300) throw new Error(`Download failed (${res.status})`);
  const ab = await res.arrayBuffer();
  return Buffer.from(ab);
}

function normalizeCropRect({ left, top, width, height }, imgW, imgH) {
  const nums = [left, top, width, height].filter((n) => typeof n === "number" && Number.isFinite(n));
  if (nums.length !== 4) return null;
  const max = Math.max(...nums.map((n) => Math.abs(n)));
  const isFractional = max <= 1.5;

  let l = left;
  let t = top;
  let w = width;
  let h = height;
  if (isFractional) {
    l = left * imgW;
    t = top * imgH;
    w = width * imgW;
    h = height * imgH;
  }

  const ll = Math.max(0, Math.min(imgW - 1, Math.round(l)));
  const tt = Math.max(0, Math.min(imgH - 1, Math.round(t)));
  const ww = Math.max(1, Math.min(imgW - ll, Math.round(w)));
  const hh = Math.max(1, Math.min(imgH - tt, Math.round(h)));
  return { left: ll, top: tt, width: ww, height: hh };
}

/**
 * Admin: import Canva current page elements into a Goal Canvas template by cropping PNG.
 *
 * Body:
 * {
 *   designId?: string,
 *   designToken?: string,
 *   elements: [{ id?, type?, left, top, width, height, rotation?, text? }]
 * }
 */
app.post("/admin/canva/import/current-page", requireAdmin(), async (req, res) => {
  if (!ensureDbOr501(res)) return;
  try {
    let designId = typeof req.body?.designId === "string" ? req.body.designId : null;
    const designToken = typeof req.body?.designToken === "string" ? req.body.designToken : null;
    if (!designId && designToken) {
      const payload = decodeJwtPayload(designToken);
      designId = typeof payload?.designId === "string" ? payload.designId : null;
    }
    if (!designId) return res.status(400).json({ error: "missing_designId" });

    const elements = Array.isArray(req.body?.elements) ? req.body.elements : null;
    if (!elements) return res.status(400).json({ error: "invalid_elements" });

    const rec = await getUserRecord(req.dvUser.canvaUserId);
    if (!rec?.canva?.access_token) return res.status(400).json({ error: "missing_canva_token" });

    // Refresh token if expired (best effort).
    let accessToken = rec.canva.access_token;
    const expiresIn = typeof rec.canva.expires_in === "number" ? rec.canva.expires_in : null;
    const obtainedAt = typeof rec.canva.obtained_at === "number" ? rec.canva.obtained_at : null;
    const refreshToken = rec.canva.refresh_token ?? null;
    const now = Date.now();
    const isExpired =
      expiresIn != null && obtainedAt != null ? now > obtainedAt + Math.max(0, expiresIn - 60) * 1000 : false;
    if (isExpired && refreshToken) {
      const fresh = await refreshAccessToken({ refreshToken });
      accessToken = fresh.access_token;
      rec.canva.access_token = fresh.access_token;
      rec.canva.refresh_token = fresh.refresh_token ?? rec.canva.refresh_token;
      rec.canva.expires_in = fresh.expires_in ?? rec.canva.expires_in;
      rec.canva.obtained_at = Date.now();
      await putUserRecord(req.dvUser.canvaUserId, rec);
    }

    const created = await createExportJob({ accessToken, designId, format: { type: "png" } });
    const startedAt = Date.now();
    let job = created;
    while (job?.status === "in_progress" && Date.now() - startedAt < 90_000) {
      await new Promise((r) => setTimeout(r, 2000));
      job = await getExportJob({ accessToken, exportId: job.id });
    }
    const urls = Array.isArray(job?.urls) ? job.urls : null;
    if (!urls?.length || typeof urls[0] !== "string") {
      return res.status(500).json({ error: "export_missing_urls", status: job?.status ?? null, jobId: job?.id ?? null });
    }

    const pngBytes = await downloadBytes(urls[0]);
    const meta = await sharp(pngBytes).metadata();
    const imgW = meta.width ?? null;
    const imgH = meta.height ?? null;
    if (!imgW || !imgH) return res.status(500).json({ error: "image_metadata_missing" });

    const components = [];
    const createdBy = req.dvUser.canvaUserId;
    let z = 0;

    for (let i = 0; i < elements.length; i++) {
      const e = elements[i] ?? {};
      const left = typeof e.left === "number" ? e.left : typeof e.x === "number" ? e.x : null;
      const top = typeof e.top === "number" ? e.top : typeof e.y === "number" ? e.y : null;
      const width = typeof e.width === "number" ? e.width : typeof e.w === "number" ? e.w : null;
      const height = typeof e.height === "number" ? e.height : typeof e.h === "number" ? e.h : null;
      if (left == null || top == null || width == null || height == null) continue;
      if (width <= 0 || height <= 0) continue;

      const rect = normalizeCropRect({ left, top, width, height }, imgW, imgH);
      if (!rect) continue;

      // Note: rotation is ignored in v1; we crop axis-aligned.
      const croppedPng = await sharp(pngBytes).extract(rect).png().toBuffer();
      const imageId = `timg_${randomId(16)}`;
      await insertTemplateImagePg({
        id: imageId,
        createdBy,
        contentType: "image/png",
        bytes: croppedPng,
      });

      const rawText = typeof e.text === "string" ? e.text.trim() : "";
      const title = rawText ? rawText.slice(0, 80) : `Layer ${i + 1}`;

      components.push({
        type: "image",
        id: `canva_layer_${randomId(10)}`,
        position: { dx: rect.left, dy: rect.top },
        size: { w: rect.width, h: rect.height },
        rotation: 0,
        scale: 1,
        zIndex: z++,
        habits: [],
        tasks: [],
        isDisabled: false,
        imagePath: templateImagePath(imageId),
        goal: { title, category: null, deadline: null, cbt_metadata: null, action_plan: null },
      });
    }

    res.json({
      ok: true,
      exportUrl: urls[0],
      imageWidth: imgW,
      imageHeight: imgH,
      template: {
        kind: "goal_canvas",
        templateJson: { components },
      },
    });
  } catch (e) {
    res.status(500).json({ error: "canva_import_failed", message: String(e?.message ?? e) });
  }
});

app.get("/canva/packages", requireDvAuth(), async (req, res) => {
  const rec = await getUserRecord(req.dvUser.canvaUserId);
  const packages = Array.isArray(rec?.packages) ? rec.packages : [];
  res.json({
    packages: packages.map((p) => ({
      id: p?.id ?? null,
      designId: p?.designId ?? null,
      title: p?.title ?? null,
      createdAt: p?.createdAt ?? null,
      hasExport: Boolean(p?.export?.urls?.length),
    })),
  });
});

app.get("/canva/packages/latest", requireDvAuth(), async (req, res) => {
  const rec = await getUserRecord(req.dvUser.canvaUserId);
  const packages = Array.isArray(rec?.packages) ? rec.packages : [];
  const latest = packages[0] ?? null;
  if (!latest) return res.status(404).json({ error: "no_packages" });
  res.json({ package: latest });
});

app.get("/canva/packages/:id", requireDvAuth(), async (req, res) => {
  const id = req.params.id;
  const rec = await getUserRecord(req.dvUser.canvaUserId);
  const packages = Array.isArray(rec?.packages) ? rec.packages : [];
  const found = packages.find((p) => p?.id === id) ?? null;
  if (!found) return res.status(404).json({ error: "package_not_found" });
  res.json({ package: found });
});

/**
 * Replace habit list (used by Canva panel; later Flutter can populate).
 * Body: { habits: [{id, name}] }
 */
app.post("/habits", requireDvAuth(), async (req, res) => {
  const habits = Array.isArray(req.body?.habits) ? req.body.habits : null;
  if (!habits) return res.status(400).json({ error: "invalid_habits" });

  const sanitized = habits
    .map((h) => ({
      id: String(h.id ?? ""),
      name: String(h.name ?? ""),
    }))
    .filter((h) => h.id && h.name);

  const rec = await getUserRecord(req.dvUser.canvaUserId);
  await putUserRecord(req.dvUser.canvaUserId, { ...rec, habits: sanitized });
  res.json({ ok: true, habits: sanitized });
});

/**
 * Store element→habit mappings and a preliminary "package".
 * Body (v1, minimal):
 * {
 *   designId: string,
 *   title?: string,
 *   mappedElements: [
 *     { elementId: string, type: "text"|"other", zIndex?: number, bounds?: {x,y,w,h}, text?: string }
 *   ],
 *   createdAt?: number
 * }
 */
app.post("/canva/sync", requireDvAuth(), async (req, res) => {
  function decodeJwtPayload(jwt) {
    // Minimal/dev-friendly decoder (no signature verification).
    // TODO: verify with Canva JWKS + expected audience when hardening.
    try {
      const parts = String(jwt).split(".");
      if (parts.length < 2) return null;
      const b64 = parts[1].replaceAll("-", "+").replaceAll("_", "/");
      const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
      const json = Buffer.from(padded, "base64").toString("utf-8");
      return JSON.parse(json);
    } catch {
      return null;
    }
  }

  // Accept either the planned backend shape OR the current Canva panel payload.
  let designId = typeof req.body?.designId === "string" ? req.body.designId : null;
  const designToken = typeof req.body?.designToken === "string" ? req.body.designToken : null;
  if (!designId && designToken) {
    const payload = decodeJwtPayload(designToken);
    designId = typeof payload?.designId === "string" ? payload.designId : null;
  }
  if (!designId) return res.status(400).json({ error: "missing_designId" });

  let mappedElements = Array.isArray(req.body?.mappedElements) ? req.body.mappedElements : [];

  // If payload looks like canva-app-panel v1: { version, selection, mappings }
  if (!mappedElements.length && req.body?.version === 1) {
    const selection = Array.isArray(req.body?.selection) ? req.body.selection : [];
    const mappings = Array.isArray(req.body?.mappings) ? req.body.mappings : [];
    const habitByKey = new Map(
      mappings
        .map((m) => [String(m?.key ?? ""), String(m?.habitId ?? "")])
        .filter(([k, h]) => k && h),
    );

    mappedElements = selection
      .map((s) => {
        const key = String(s?.key ?? "");
        const habitId = habitByKey.get(key);
        if (!habitId) return null;
        const b = s?.bounds ?? {};
        return {
          selectionKey: key,
          habitId,
          elementId: typeof s?.elementId === "string" ? s.elementId : null,
          kind: typeof s?.kind === "string" ? s.kind : "unknown",
          bounds:
            b && (b.left != null || b.top != null || b.width != null || b.height != null)
              ? {
                  x: typeof b.left === "number" ? b.left : null,
                  y: typeof b.top === "number" ? b.top : null,
                  w: typeof b.width === "number" ? b.width : null,
                  h: typeof b.height === "number" ? b.height : null,
                  rotation: typeof b.rotation === "number" ? b.rotation : null,
                }
              : null,
          raw: s?.raw ?? null,
        };
      })
      .filter(Boolean);
  }

  const pkg = {
    id: randomId(12),
    designId,
    title: typeof req.body?.title === "string" ? req.body.title : null,
    mappedElements,
    createdAt: typeof req.body?.createdAt === "number" ? req.body.createdAt : Date.now(),
    export: null, // filled by task-3 (backend-export)
  };

  const rec = await getUserRecord(req.dvUser.canvaUserId);
  const packages = Array.isArray(rec?.packages) ? rec.packages : [];
  packages.unshift(pkg);
  await putUserRecord(req.dvUser.canvaUserId, { ...rec, packages });

  res.json({ ok: true, packageId: pkg.id });
});

/**
 * Export a Canva design to PNG (server-side) and attach URLs to a stored package.
 * Body: { packageId: string, format?: object }
 */
app.post("/canva/export", requireDvAuth(), async (req, res) => {
  try {
    const packageId = typeof req.body?.packageId === "string" ? req.body.packageId : null;
    if (!packageId) return res.status(400).json({ error: "missing_packageId" });

    const rec = await getUserRecord(req.dvUser.canvaUserId);
    if (!rec?.canva?.access_token) return res.status(400).json({ error: "missing_canva_token" });

    const packages = Array.isArray(rec.packages) ? rec.packages : [];
    const idx = packages.findIndex((p) => p?.id === packageId);
    if (idx < 0) return res.status(404).json({ error: "package_not_found" });

    const pkg = packages[idx];
    const designId = pkg?.designId;
    if (!designId) return res.status(400).json({ error: "package_missing_designId" });

    // Refresh token if expired (best effort).
    let accessToken = rec.canva.access_token;
    const expiresIn = typeof rec.canva.expires_in === "number" ? rec.canva.expires_in : null;
    const obtainedAt = typeof rec.canva.obtained_at === "number" ? rec.canva.obtained_at : null;
    const refreshToken = rec.canva.refresh_token ?? null;
    const now = Date.now();
    const isExpired =
      expiresIn != null && obtainedAt != null ? now > obtainedAt + Math.max(0, expiresIn - 60) * 1000 : false;
    if (isExpired && refreshToken) {
      const fresh = await refreshAccessToken({ refreshToken });
      accessToken = fresh.access_token;
      rec.canva.access_token = fresh.access_token;
      rec.canva.refresh_token = fresh.refresh_token ?? rec.canva.refresh_token;
      rec.canva.expires_in = fresh.expires_in ?? rec.canva.expires_in;
      rec.canva.obtained_at = Date.now();
      await putUserRecord(req.dvUser.canvaUserId, rec);
    }

    const format = typeof req.body?.format === "object" && req.body.format ? req.body.format : { type: "png" };
    const created = await createExportJob({ accessToken, designId, format });

    // Poll until done (simple, synchronous; keep minimal for now).
    const startedAt = Date.now();
    let job = created;
    while (job?.status === "in_progress" && Date.now() - startedAt < 90_000) {
      await new Promise((r) => setTimeout(r, 2000));
      job = await getExportJob({ accessToken, exportId: job.id });
    }

    const exportInfo = {
      jobId: job?.id ?? created.id,
      status: job?.status ?? "unknown",
      urls: Array.isArray(job?.urls) ? job.urls : null,
      error: job?.error ?? null,
      format,
      finishedAt: Date.now(),
    };

    packages[idx] = { ...pkg, export: exportInfo };
    await putUserRecord(req.dvUser.canvaUserId, { ...rec, packages });

    res.json({ ok: true, packageId, export: exportInfo });
  } catch (e) {
    res.status(500).json({ error: "export_failed", message: String(e?.message ?? e) });
  }
});

// ---- Sync APIs (Phase A) ----
const SYNC_RETAIN_DAYS = Number(process.env.SYNC_RETAIN_DAYS ?? 90);

app.put("/user/settings", requireDvAuth(), async (req, res) => {
  if (!hasDatabase()) return res.status(501).json({ error: "database_required" });
  const homeTimezone = typeof req.body?.home_timezone === "string" ? req.body.home_timezone : null;
  await putUserSettingsPg(req.dvUser.canvaUserId, { homeTimezone });
  res.json({ ok: true, home_timezone: homeTimezone });
});

app.get("/sync/bootstrap", requireDvAuth(), async (req, res) => {
  if (!hasDatabase()) return res.status(501).json({ error: "database_required" });
  const days = Number.isFinite(SYNC_RETAIN_DAYS) && SYNC_RETAIN_DAYS > 0 ? SYNC_RETAIN_DAYS : 90;

  // Best-effort retention to keep server storage bounded.
  await cleanupOldLogsPg(req.dvUser.canvaUserId, days);

  const [settings, boards, habitCompletions, checklistEvents] = await Promise.all([
    getUserSettingsPg(req.dvUser.canvaUserId),
    listBoardsPg(req.dvUser.canvaUserId),
    getRecentHabitCompletionsPg(req.dvUser.canvaUserId, days),
    getRecentChecklistEventsPg(req.dvUser.canvaUserId, days),
  ]);

  res.json({
    ok: true,
    home_timezone: settings?.homeTimezone ?? null,
    boards,
    habit_completions: habitCompletions,
    checklist_events: checklistEvents,
    retain_days: days,
  });
});

/**
 * Push a batch of recent mutations (idempotent).
 * Body:
 * {
 *   boards?: [{ boardId, boardJson }],
 *   userSettings?: { homeTimezone },
 *   habitCompletions?: [{ boardId, componentId, habitId, logicalDate, rating?, note?, deleted? }],
 *   checklistEvents?: [{ boardId, componentId, taskId, itemId, logicalDate, rating?, note?, deleted? }]
 * }
 */
app.post("/sync/push", requireDvAuth(), async (req, res) => {
  if (!hasDatabase()) return res.status(501).json({ error: "database_required" });
  const days = Number.isFinite(SYNC_RETAIN_DAYS) && SYNC_RETAIN_DAYS > 0 ? SYNC_RETAIN_DAYS : 90;

  const body = req.body ?? {};
  await applySyncPushPg(req.dvUser.canvaUserId, {
    boards: Array.isArray(body?.boards) ? body.boards : null,
    userSettings: typeof body?.userSettings === "object" && body.userSettings ? body.userSettings : null,
    habitCompletions: Array.isArray(body?.habitCompletions) ? body.habitCompletions : null,
    checklistEvents: Array.isArray(body?.checklistEvents) ? body.checklistEvents : null,
    retainDays: days,
  });

  res.json({ ok: true });
});

const port = Number(process.env.PORT ?? 8787);
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`Backend listening on http://localhost:${port}`);
});

