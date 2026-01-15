const CANVA_TOKEN_URL = "https://api.canva.com/rest/v1/oauth/token";
const CANVA_USERS_ME_URL = "https://api.canva.com/rest/v1/users/me";
const CANVA_EXPORTS_URL = "https://api.canva.com/rest/v1/exports";

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var ${name}`);
  return v;
}

function basicAuthHeader(clientId, clientSecret) {
  const token = Buffer.from(`${clientId}:${clientSecret}`, "utf-8").toString("base64");
  return `Basic ${token}`;
}

export function canvaAuthorizeUrl({ state, codeChallenge }) {
  const clientId = requireEnv("CANVA_CLIENT_ID");
  const redirectUri = process.env.CANVA_REDIRECT_URI ?? `${requireEnv("BASE_URL")}/auth/canva/callback`;
  const scope = process.env.CANVA_SCOPES ?? "design:content:read profile:read";

  const url = new URL("https://www.canva.com/api/oauth/authorize");
  url.searchParams.set("response_type", "code");
  url.searchParams.set("client_id", clientId);
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("scope", scope);
  url.searchParams.set("state", state);
  url.searchParams.set("code_challenge_method", "s256");
  url.searchParams.set("code_challenge", codeChallenge);
  return url.toString();
}

export async function exchangeAuthorizationCode({ code, codeVerifier }) {
  const clientId = requireEnv("CANVA_CLIENT_ID");
  const clientSecret = requireEnv("CANVA_CLIENT_SECRET");
  const redirectUri = process.env.CANVA_REDIRECT_URI ?? `${requireEnv("BASE_URL")}/auth/canva/callback`;

  const form = new URLSearchParams();
  form.set("grant_type", "authorization_code");
  form.set("code", code);
  form.set("redirect_uri", redirectUri);
  form.set("code_verifier", codeVerifier);

  const res = await fetch(CANVA_TOKEN_URL, {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
      authorization: basicAuthHeader(clientId, clientSecret),
    },
    body: form,
  });

  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`Canva token exchange failed: ${res.status} ${JSON.stringify(json)}`);
  }
  return json; // contains access_token, refresh_token, expires_in, token_type
}

export async function refreshAccessToken({ refreshToken }) {
  const clientId = requireEnv("CANVA_CLIENT_ID");
  const clientSecret = requireEnv("CANVA_CLIENT_SECRET");

  const form = new URLSearchParams();
  form.set("grant_type", "refresh_token");
  form.set("refresh_token", refreshToken);

  const res = await fetch(CANVA_TOKEN_URL, {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
      authorization: basicAuthHeader(clientId, clientSecret),
    },
    body: form,
  });

  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`Canva token refresh failed: ${res.status} ${JSON.stringify(json)}`);
  }
  return json;
}

export async function getUsersMe(accessToken) {
  const res = await fetch(CANVA_USERS_ME_URL, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`Canva users/me failed: ${res.status} ${JSON.stringify(json)}`);
  }
  return json;
}

export async function createExportJob({ accessToken, designId, format }) {
  const res = await fetch(CANVA_EXPORTS_URL, {
    method: "POST",
    headers: {
      authorization: `Bearer ${accessToken}`,
      "content-type": "application/json",
      accept: "application/json",
    },
    body: JSON.stringify({
      design_id: designId,
      format: format ?? { type: "png" },
    }),
  });
  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`Canva create export failed: ${res.status} ${JSON.stringify(json)}`);
  }
  const job = json?.job ?? null;
  if (!job?.id) throw new Error(`Canva create export: missing job id (${JSON.stringify(json)})`);
  return job;
}

export async function getExportJob({ accessToken, exportId }) {
  const res = await fetch(`${CANVA_EXPORTS_URL}/${exportId}`, {
    headers: { authorization: `Bearer ${accessToken}`, accept: "application/json" },
  });
  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`Canva get export failed: ${res.status} ${JSON.stringify(json)}`);
  }
  return json?.job ?? json;
}

