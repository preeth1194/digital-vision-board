import { findUserByDvToken } from "./storage.js";

export function requireDvAuth() {
  return async (req, res, next) => {
    const header = req.headers.authorization ?? "";
    const m = /^Bearer\s+(.+)$/.exec(header);
    const dvToken = m?.[1];
    if (!dvToken) return res.status(401).json({ error: "missing_auth" });

    const user = await findUserByDvToken(dvToken);
    if (!user) return res.status(401).json({ error: "invalid_auth" });

    // Guest tokens expire server-side. (Non-guest tokens remain valid.)
    if (user?.isGuest) {
      const expiresAtMs = typeof user?.guestExpiresAtMs === "number" ? user.guestExpiresAtMs : null;
      if (expiresAtMs != null && Date.now() > expiresAtMs) {
        return res.status(401).json({
          error: "expired_auth",
          expiresAt: new Date(expiresAtMs).toISOString(),
        });
      }
    }

    req.dvUser = user;
    next();
  };
}

function devAdminBypassEnabled() {
  // Explicit opt-in only; never enable by default.
  return String(process.env.DV_ALLOW_DEV_ADMIN ?? "").trim().toLowerCase() == "true";
}

function parseAdminUserIds() {
  const raw = String(process.env.DV_ADMIN_USER_IDS ?? "");
  return raw
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

export function requireAdmin() {
  const allowed = new Set(parseAdminUserIds());
  return async (req, res, next) => {
    await requireDvAuth()(req, res, () => {});
    if (!req.dvUser) return; // requireDvAuth already responded

    // Local development escape hatch.
    // Use ONLY in local/dev environments by setting DV_ALLOW_DEV_ADMIN=true on the backend.
    if (devAdminBypassEnabled()) {
      return next();
    }

    const id = req.dvUser?.canvaUserId;
    if (!id || !allowed.has(id)) {
      return res.status(403).json({ error: "forbidden", message: "Admin access required." });
    }
    next();
  };
}
