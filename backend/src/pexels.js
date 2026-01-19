import fs from "node:fs/promises";
import path from "node:path";

const dataDir = path.resolve(process.cwd(), "data");
const tmpDir = path.resolve(process.cwd(), "tmp");

function cacheFile() {
  return path.join(dataDir, "pexels_cache.json");
}

async function ensureDir(dirPath) {
  await fs.mkdir(dirPath, { recursive: true });
}

async function atomicWriteJson(filePath, obj) {
  await ensureDir(path.dirname(filePath));
  await ensureDir(tmpDir);
  const tmpPath = path.join(tmpDir, `.${path.basename(filePath)}.${Date.now()}.tmp`);
  await fs.writeFile(tmpPath, JSON.stringify(obj, null, 2), "utf-8");
  await fs.rename(tmpPath, filePath);
}

async function readJson(filePath, fallback) {
  try {
    const raw = await fs.readFile(filePath, "utf-8");
    return JSON.parse(raw);
  } catch {
    return fallback;
  }
}

function normalizeQuery(q) {
  return String(q ?? "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

function clampInt(n, lo, hi) {
  const x = Number.isFinite(Number(n)) ? Math.trunc(Number(n)) : lo;
  return Math.max(lo, Math.min(hi, x));
}

/**
 * Search Pexels for photos.
 *
 * Returns:
 * { ok: true, query, photos: [{ id, alt, url, photographer, src: { small, medium, large, original } }] }
 */
export async function searchPexelsPhotos({ query, perPage = 12, ttlMs = 6 * 60 * 60 * 1000 }) {
  const apiKey = String(process.env.PEXELS_API_KEY ?? "").trim();
  if (!apiKey) {
    return { ok: false, error: "pexels_api_key_missing" };
  }

  const q = normalizeQuery(query);
  if (!q) return { ok: false, error: "missing_query" };
  const pp = clampInt(perPage, 1, 30);

  // File cache (works in both DB and non-DB modes; keeps costs low).
  const all = await readJson(cacheFile(), {});
  const key = `${q}::${pp}`;
  const hit = all[key];
  const now = Date.now();
  if (hit && typeof hit === "object") {
    const cachedAt = Number(hit.cachedAtMs ?? 0);
    if (cachedAt > 0 && now - cachedAt < ttlMs && Array.isArray(hit.photos)) {
      return { ok: true, query: q, cached: true, photos: hit.photos };
    }
  }

  const url = new URL("https://api.pexels.com/v1/search");
  url.searchParams.set("query", q);
  url.searchParams.set("per_page", String(pp));
  // Portrait works better for collage-y boards; users can still replace.
  url.searchParams.set("orientation", "portrait");

  const res = await fetch(url, {
    method: "GET",
    headers: {
      Authorization: apiKey,
      Accept: "application/json",
    },
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    return { ok: false, error: "pexels_request_failed", status: res.status, body: body.slice(0, 500) };
  }

  const json = await res.json();
  const photosRaw = Array.isArray(json?.photos) ? json.photos : [];
  const photos = photosRaw
    .map((p) => {
      if (!p || typeof p !== "object") return null;
      const id = p.id ?? null;
      const src = p.src ?? {};
      const small = src.small ?? null;
      const medium = src.medium ?? null;
      const large = src.large ?? null;
      const original = src.original ?? null;
      if (!medium && !large && !original && !small) return null;
      return {
        id,
        alt: typeof p.alt === "string" ? p.alt : "",
        url: typeof p.url === "string" ? p.url : "",
        photographer: typeof p.photographer === "string" ? p.photographer : "",
        src: {
          small: typeof small === "string" ? small : null,
          medium: typeof medium === "string" ? medium : null,
          large: typeof large === "string" ? large : null,
          original: typeof original === "string" ? original : null,
        },
      };
    })
    .filter(Boolean);

  all[key] = { cachedAtMs: now, photos };
  await atomicWriteJson(cacheFile(), all);
  return { ok: true, query: q, cached: false, photos };
}

