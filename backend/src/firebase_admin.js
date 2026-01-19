import admin from "firebase-admin";

let _initialized = false;

function _tryParseServiceAccountJson(raw) {
  try {
    const obj = JSON.parse(String(raw));
    return obj && typeof obj === "object" ? obj : null;
  } catch {
    return null;
  }
}

/**
 * Initialize firebase-admin exactly once.
 *
 * Supported env options:
 * - FIREBASE_SERVICE_ACCOUNT_JSON: JSON string for service account
 * - GOOGLE_APPLICATION_CREDENTIALS: file path (standard google auth)
 *
 * If neither is set, verification will fail; callers should handle errors.
 */
export function ensureFirebaseAdmin() {
  if (_initialized) return;
  if (admin.apps?.length) {
    _initialized = true;
    return;
  }

  const saJson = String(process.env.FIREBASE_SERVICE_ACCOUNT_JSON ?? "").trim();
  if (saJson) {
    const serviceAccount = _tryParseServiceAccountJson(saJson);
    if (!serviceAccount) {
      throw new Error("Invalid FIREBASE_SERVICE_ACCOUNT_JSON (must be valid JSON).");
    }
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    _initialized = true;
    return;
  }

  // Falls back to application default credentials if configured.
  admin.initializeApp();
  _initialized = true;
}

export { admin };

