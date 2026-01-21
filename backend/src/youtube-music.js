const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const YOUTUBE_API_BASE = "https://www.googleapis.com/youtube/v3";

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var ${name}`);
  return v;
}

function basicAuthHeader(clientId, clientSecret) {
  const token = Buffer.from(`${clientId}:${clientSecret}`, "utf-8").toString("base64");
  return `Basic ${token}`;
}

export function youtubeMusicAuthorizeUrl({ state, codeChallenge }) {
  const clientId = requireEnv("YOUTUBE_MUSIC_CLIENT_ID");
  const redirectUri = process.env.YOUTUBE_MUSIC_REDIRECT_URI ?? `${requireEnv("BASE_URL")}/auth/youtube-music/callback`;
  const scope = process.env.YOUTUBE_MUSIC_SCOPES ?? "https://www.googleapis.com/auth/youtube.readonly";

  const url = new URL("https://accounts.google.com/o/oauth2/v2/auth");
  url.searchParams.set("response_type", "code");
  url.searchParams.set("client_id", clientId);
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("scope", scope);
  url.searchParams.set("state", state);
  url.searchParams.set("code_challenge_method", "S256");
  url.searchParams.set("code_challenge", codeChallenge);
  url.searchParams.set("access_type", "offline");
  url.searchParams.set("prompt", "consent");
  return url.toString();
}

export async function exchangeAuthorizationCode({ code, codeVerifier }) {
  const clientId = requireEnv("YOUTUBE_MUSIC_CLIENT_ID");
  const clientSecret = requireEnv("YOUTUBE_MUSIC_CLIENT_SECRET");
  const redirectUri = process.env.YOUTUBE_MUSIC_REDIRECT_URI ?? `${requireEnv("BASE_URL")}/auth/youtube-music/callback`;

  const form = new URLSearchParams();
  form.set("grant_type", "authorization_code");
  form.set("code", code);
  form.set("redirect_uri", redirectUri);
  form.set("code_verifier", codeVerifier);
  form.set("client_id", clientId);
  form.set("client_secret", clientSecret);

  const res = await fetch(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
    },
    body: form,
  });

  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`YouTube Music token exchange failed: ${res.status} ${JSON.stringify(json)}`);
  }
  return json; // contains access_token, refresh_token, expires_in, token_type
}

export async function refreshAccessToken({ refreshToken }) {
  const clientId = requireEnv("YOUTUBE_MUSIC_CLIENT_ID");
  const clientSecret = requireEnv("YOUTUBE_MUSIC_CLIENT_SECRET");

  const form = new URLSearchParams();
  form.set("grant_type", "refresh_token");
  form.set("refresh_token", refreshToken);
  form.set("client_id", clientId);
  form.set("client_secret", clientSecret);

  const res = await fetch(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
    },
    body: form,
  });

  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`YouTube Music token refresh failed: ${res.status} ${JSON.stringify(json)}`);
  }
  return json;
}

async function getValidAccessToken(userRecord) {
  const youtubeMusic = userRecord?.youtubeMusic;
  if (!youtubeMusic?.access_token) {
    throw new Error("YouTube Music not connected");
  }

  // Check if token is expired (with 60 second buffer)
  const obtainedAt = youtubeMusic.obtained_at ?? 0;
  const expiresIn = youtubeMusic.expires_in ?? 3600;
  const expiresAt = obtainedAt + expiresIn * 1000;
  const now = Date.now();

  if (now >= expiresAt - 60000) {
    // Token expired or about to expire, refresh it
    if (!youtubeMusic.refresh_token) {
      throw new Error("YouTube Music token expired and no refresh token available");
    }

    const refreshed = await refreshAccessToken({ refreshToken: youtubeMusic.refresh_token });
    // Update user record with new tokens (caller should save this)
    youtubeMusic.access_token = refreshed.access_token;
    youtubeMusic.obtained_at = Date.now();
    youtubeMusic.expires_in = refreshed.expires_in ?? 3600;
    if (refreshed.refresh_token) {
      youtubeMusic.refresh_token = refreshed.refresh_token;
    }
    if (refreshed.token_type) {
      youtubeMusic.token_type = refreshed.token_type;
    }
  }

  return youtubeMusic.access_token;
}

export async function getPlaylists(userRecord, { limit = 50, offset = 0 } = {}) {
  const accessToken = await getValidAccessToken(userRecord);
  const url = new URL(`${YOUTUBE_API_BASE}/playlists`);
  url.searchParams.set("part", "snippet,contentDetails");
  url.searchParams.set("mine", "true");
  url.searchParams.set("maxResults", String(limit));
  url.searchParams.set("pageToken", offset > 0 ? String(offset) : "");

  const res = await fetch(url.toString(), {
    headers: {
      authorization: `Bearer ${accessToken}`,
      accept: "application/json",
    },
  });

  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`YouTube Music get playlists failed: ${res.status} ${JSON.stringify(json)}`);
  }

  return json.items?.map((item) => ({
    id: item.id,
    name: item.snippet?.title ?? "Untitled Playlist",
    imageUrl: item.snippet?.thumbnails?.high?.url ?? item.snippet?.thumbnails?.medium?.url ?? item.snippet?.thumbnails?.default?.url ?? null,
    ownerName: item.snippet?.channelTitle ?? null,
    trackCount: item.contentDetails?.itemCount ?? null,
  })) ?? [];
}

export async function searchTracks(userRecord, query, { limit = 20 } = {}) {
  const accessToken = await getValidAccessToken(userRecord);
  const url = new URL(`${YOUTUBE_API_BASE}/search`);
  url.searchParams.set("part", "snippet");
  url.searchParams.set("q", query);
  url.searchParams.set("type", "video");
  url.searchParams.set("maxResults", String(limit));
  url.searchParams.set("videoCategoryId", "10"); // Music category

  const res = await fetch(url.toString(), {
    headers: {
      authorization: `Bearer ${accessToken}`,
      accept: "application/json",
    },
  });

  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`YouTube Music search tracks failed: ${res.status} ${JSON.stringify(json)}`);
  }

  return json.items?.map((item) => {
    const snippet = item.snippet;
    // Extract artist from title (common pattern: "Song Name - Artist Name")
    const titleParts = snippet?.title?.split(" - ") ?? [];
    const name = titleParts[0] ?? snippet?.title ?? "Unknown";
    const artist = titleParts.length > 1 ? titleParts.slice(1).join(" - ") : snippet?.channelTitle ?? "";

    return {
      id: item.id?.videoId ?? item.id,
      name: name,
      artist: artist,
      album: snippet?.channelTitle ?? null,
      imageUrl: snippet?.thumbnails?.high?.url ?? snippet?.thumbnails?.medium?.url ?? snippet?.thumbnails?.default?.url ?? null,
      durationMs: null, // YouTube API doesn't provide duration in search results
    };
  }) ?? [];
}

export async function getPlaylistTracks(userRecord, playlistId, { limit = 100, offset = 0 } = {}) {
  const accessToken = await getValidAccessToken(userRecord);
  const url = new URL(`${YOUTUBE_API_BASE}/playlistItems`);
  url.searchParams.set("part", "snippet,contentDetails");
  url.searchParams.set("playlistId", playlistId);
  url.searchParams.set("maxResults", String(limit));
  url.searchParams.set("pageToken", offset > 0 ? String(offset) : "");

  const res = await fetch(url.toString(), {
    headers: {
      authorization: `Bearer ${accessToken}`,
      accept: "application/json",
    },
  });

  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`YouTube Music get playlist tracks failed: ${res.status} ${JSON.stringify(json)}`);
  }

  return json.items
    ?.filter((item) => item.snippet?.title !== "Private video" && item.snippet?.title !== "Deleted video")
    ?.map((item) => {
      const snippet = item.snippet;
      const titleParts = snippet?.title?.split(" - ") ?? [];
      const name = titleParts[0] ?? snippet?.title ?? "Unknown";
      const artist = titleParts.length > 1 ? titleParts.slice(1).join(" - ") : snippet?.videoOwnerChannelTitle ?? "";

      return {
        id: item.contentDetails?.videoId ?? item.id,
        name: name,
        artist: artist,
        album: snippet?.videoOwnerChannelTitle ?? null,
        imageUrl: snippet?.thumbnails?.high?.url ?? snippet?.thumbnails?.medium?.url ?? snippet?.thumbnails?.default?.url ?? null,
        durationMs: null, // Would need additional API call to get duration
      };
    }) ?? [];
}

export { getValidAccessToken };
