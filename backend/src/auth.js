import { findUserByDvToken } from "./storage.js";

export function requireDvAuth() {
  return async (req, res, next) => {
    const header = req.headers.authorization ?? "";
    const m = /^Bearer\s+(.+)$/.exec(header);
    const dvToken = m?.[1];
    if (!dvToken) return res.status(401).json({ error: "missing_auth" });

    const user = await findUserByDvToken(dvToken);
    if (!user) return res.status(401).json({ error: "invalid_auth" });

    req.dvUser = user;
    next();
  };
}

