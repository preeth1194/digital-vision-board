const SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token";
const SPOTIFY_API_BASE = "https://api.spotify.com/v1";

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var ${name}`);
  return v;
}

function basicAuthHeader(clientId, clientSecret) {
  const token = Buffer.from(`${clientId}:${clientSecret}`, "utf-8").toString("base64");
  return `Basic ${token}`;
}

export function spotifyAuthorizeUrl({ state, codeChallenge }) {
  const clientId = requireEnv("SPOTIFY_CLIENT_ID");
  const redirectUri = process.env.SPOTIFY_REDIRECT_URI ?? `${requireEnv("BASE_URL")}/auth/spotify/callback`;
  const scope = process.env.SPOTIFY_SCOPES ?? "user-read-private user-read-email playlist-read-private playlist-read-collaborative user-library-read";

  const url = new URL("https://accounts.spotify.com/authorize");
  url.searchParams.set("response_type", "code");
  url.searchParams.set("client_id", clientId);
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("scope", scope);
  url.searchParams.set("state", state);
  url.searchParams.set("code_challenge_method", "S256");
  url.searchParams.set("code_challenge", codeChallenge);
  return url.toString();
}

export async function exchangeAuthorizationCode({ code, codeVerifier }) {
  const clientId = requireEnv("SPOTIFY_CLIENT_ID");
  const clientSecret = requireEnv("SPOTIFY_CLIENT_SECRET");
  const redirectUri = process.env.SPOTIFY_REDIRECT_URI ?? `${requireEnv("BASE_URL")}/auth/spotify/callback`;

  const form = new URLSearchParams();
  form.set("grant_type", "authorization_code");
  form.set("code", code);
  form.set("redirect_uri", redirectUri);
  form.set("code_verifier", codeVerifier);

  const res = await fetch(SPOTIFY_TOKEN_URL, {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
      authorization: basicAuthHeader(clientId, clientSecret),
    },
    body: form,
  });

  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`Spotify token exchange failed: ${res.status} ${JSON.stringify(json)}`);
  }
  return json; // contains access_token, refresh_token, expires_in, token_type
}

export async function refreshAccessToken({ refreshToken }) {
  const clientId = requireEnv("SPOTIFY_CLIENT_ID");
  const clientSecret = requireEnv("SPOTIFY_CLIENT_SECRET");

  const form = new URLSearchParams();
  form.set("grant_type", "refresh_token");
  form.set("refresh_token", refreshToken);

  const res = await fetch(SPOTIFY_TOKEN_URL, {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
      authorization: basicAuthHeader(clientId, clientSecret),
    },
    body: form,
  });

  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`Spotify token refresh failed: ${res.status} ${JSON.stringify(json)}`);
  }
  return json;
}

async function getValidAccessToken(userRecord) {
  const spotify = userRecord?.spotify;
  if (!spotify?.access_token) {
    throw new Error("Spotify not connected");
  }

  // Check if token is expired (with 60 second buffer)
  const obtainedAt = spotify.obtained_at ?? 0;
  const expiresIn = spotify.expires_in ?? 3600;
  const expiresAt = obtainedAt + expiresIn * 1000;
  const now = Date.now();

  if (now >= expiresAt - 60000) {
    // Token expired or about to expire, refresh it
    if (!spotify.refresh_token) {
      throw new Error("Spotify token expired and no refresh token available");
    }

    const refreshed = await refreshAccessToken({ refreshToken: spotify.refresh_token });
    // Update user record with new tokens (caller should save this)
    spotify.access_token = refreshed.access_token;
    spotify.obtained_at = Date.now();
    spotify.expires_in = refreshed.expires_in ?? 3600;
    if (refreshed.refresh_token) {
      spotify.refresh_token = refreshed.refresh_token;
    }
    if (refreshed.token_type) {
      spotify.token_type = refreshed.token_type;
    }
  }

  return spotify.access_token;
}

export async function getPlaylists(userRecord, { limit = 50, offset = 0 } = {}) {
  const accessToken = await getValidAccessToken(userRecord);
  const url = new URL(`${SPOTIFY_API_BASE}/me/playlists`);
  url.searchParams.set("limit", String(limit));
  url.searchParams.set("offset", String(offset));

  const res = await fetch(url.toString(), {
    headers: {
      authorization: `Bearer ${accessToken}`,
      accept: "application/json",
    },
  });

  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`Spotify get playlists failed: ${res.status} ${JSON.stringify(json)}`);
  }

  return json.items?.map((item) => ({
    id: item.id,
    name: item.name,
    imageUrl: item.images?.[0]?.url ?? null,
    ownerName: item.owner?.display_name ?? null,
    trackCount: item.tracks?.total ?? null,
  })) ?? [];
}

export async function searchTracks(userRecord, query, { limit = 20 } = {}) {
  const accessToken = await getValidAccessToken(userRecord);
  const url = new URL(`${SPOTIFY_API_BASE}/search`);
  url.searchParams.set("q", query);
  url.searchParams.set("type", "track");
  url.searchParams.set("limit", String(limit));

  const res = await fetch(url.toString(), {
    headers: {
      authorization: `Bearer ${accessToken}`,
      accept: "application/json",
    },
  });

  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`Spotify search tracks failed: ${res.status} ${JSON.stringify(json)}`);
  }

  return json.tracks?.items?.map((item) => ({
    id: item.id,
    name: item.name,
    artist: item.artists?.map((a) => a.name).join(", ") ?? "",
    album: item.album?.name ?? "",
    imageUrl: item.album?.images?.[0]?.url ?? null,
    durationMs: item.duration_ms ?? null,
  })) ?? [];
}

export async function getPlaylistTracks(userRecord, playlistId, { limit = 100, offset = 0 } = {}) {
  const accessToken = await getValidAccessToken(userRecord);
  const url = new URL(`${SPOTIFY_API_BASE}/playlists/${playlistId}/tracks`);
  url.searchParams.set("limit", String(limit));
  url.searchParams.set("offset", String(offset));

  const res = await fetch(url.toString(), {
    headers: {
      authorization: `Bearer ${accessToken}`,
      accept: "application/json",
    },
  });

  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`Spotify get playlist tracks failed: ${res.status} ${JSON.stringify(json)}`);
  }

  return json.items
    ?.filter((item) => item.track && !item.track.is_local)
    ?.map((item) => ({
      id: item.track.id,
      name: item.track.name,
      artist: item.track.artists?.map((a) => a.name).join(", ") ?? "",
      album: item.track.album?.name ?? "",
      imageUrl: item.track.album?.images?.[0]?.url ?? null,
      durationMs: item.track.duration_ms ?? null,
    })) ?? [];
}

export { getValidAccessToken };
