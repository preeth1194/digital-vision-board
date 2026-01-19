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
import {
  getWizardDefaults,
  getWizardRecommendations,
  putWizardDefaults,
  upsertWizardRecommendations,
} from "./wizard_storage.js";
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
import { generateWizardRecommendationsBatchWithGemini, generateWizardRecommendationsWithGemini } from "./gemini.js";
import { searchPexelsPhotos } from "./pexels.js";
import { listStockCategoryImagesPg, upsertStockCategoryImagePg } from "./stock_category_images_pg.js";

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

// In-memory job tracker for long-running admin operations (Render/mobile requests can time out).
// This keeps the HTTP request short and lets clients poll.
const wizardSyncJobs = new Map(); // jobId -> { ...status }
const stockImagesSyncJobs = new Map(); // jobId -> { ...status }

function normalizeCategoryKey(category) {
  return String(category ?? "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

function normalizeCoreValueKey(coreValueId) {
  return String(coreValueId ?? "").trim();
}

function normalizeGenderKey(gender) {
  const v = String(gender ?? "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "_");
  if (v === "male") return "male";
  if (v === "female") return "female";
  if (v === "non_binary" || v === "nonbinary") return "non_binary";
  if (v === "prefer_not_to_say" || v === "pnts" || v === "na" || v === "none") return "prefer_not_to_say";
  return "prefer_not_to_say";
}

function defaultWizardDefaults() {
  // Backend source-of-truth defaults.
  // Mirrors Flutter `CoreValues` + `WizardCoreValueCatalog.predefinedCategories` (server owns canonical list).
  return {
    coreValues: [
      { id: "growth_mindset", label: "Growth & Mindset" },
      { id: "career_ambition", label: "Career & Ambition" },
      { id: "creativity_expression", label: "Creativity & Expression" },
      { id: "lifestyle_adventure", label: "Lifestyle & Adventure" },
      { id: "connection_community", label: "Connection & Community" },
    ],
    categoriesByCoreValueId: {
      growth_mindset: ["Health", "Learning", "Mindfulness", "Confidence"],
      career_ambition: ["Skills", "Promotion", "Income", "Leadership"],
      creativity_expression: ["Art", "Writing", "Music", "Content"],
      lifestyle_adventure: ["Travel", "Fitness", "Experiences", "Home"],
      connection_community: ["Family", "Friends", "Community", "Relationships"],
    },
  };
}

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
        "- GET /auth/canva/start_poll",
        "- GET /auth/canva/poll?pollToken=...",
        "- GET /auth/canva/start",
        "- GET /canva/connect (alias)",
        "- GET /templates",
      ].join("\n"),
    );
});

app.get("/health", (req, res) => res.json({ ok: true }));

// ---- Stock images (Pexels proxy; key stays on backend) ----
app.get("/stock/pexels/search", async (req, res) => {
  try {
    const query = typeof req.query.query === "string" ? req.query.query : "";
    const perPage = typeof req.query.perPage === "string" ? Number(req.query.perPage) : undefined;
    const result = await searchPexelsPhotos({ query, perPage });
    if (!result.ok) return res.status(400).json(result);
    return res.json(result);
  } catch (e) {
    res.status(500).json({ ok: false, error: "pexels_search_failed", message: String(e?.message ?? e) });
  }
});

function buildStockQuery({ coreValueLabel, categoryLabel }) {
  // Keep queries deterministic and “vision-board friendly”.
  // Add “minimal / simple / aesthetic” bias to reduce noisy results.
  const cat = String(categoryLabel ?? "").trim();
  const core = String(coreValueLabel ?? "").trim();
  const key = normalizeCategoryKey(cat);
  const hintsByCategory = {
    health: "wellness healthy lifestyle calm",
    learning: "books study desk focus",
    mindfulness: "meditation zen calm minimal",
    confidence: "confident portrait self belief",
    skills: "workspace laptop craft focus",
    promotion: "career success office professional",
    income: "finance money savings freedom",
    leadership: "leader team meeting vision",
    art: "art studio creative minimal",
    writing: "writing notebook journaling minimal",
    music: "music instrument practice minimal",
    content: "content creation camera creator",
    travel: "travel destination adventure minimalist",
    fitness: "fitness workout gym strength",
    experiences: "adventure experience outdoors lifestyle",
    home: "minimal home interior cozy clean",
    family: "family together warm",
    friends: "friends laughing connection",
    community: "community volunteering together",
    relationships: "relationship couple love connection",
  };
  const hint = hintsByCategory[key] ?? "";
  const parts = [cat, core, hint, "minimal", "simple", "clean", "aesthetic"].filter(Boolean);
  // Keep length reasonable for search relevance.
  return parts.join(" ").replace(/\s+/g, " ").trim();
}

function defaultWizardCoreLabel(coreValueId) {
  const cv = normalizeCoreValueKey(coreValueId);
  const defaults = defaultWizardDefaults();
  const found = Array.isArray(defaults?.coreValues) ? defaults.coreValues.find((c) => c?.id === cv) : null;
  return found?.label ?? cv;
}

// ---- Stock category images (cached in DB) ----
app.get("/stock/category-images", async (req, res) => {
  try {
    if (!ensureDbOr501(res)) return;
    const coreValueId = typeof req.query.coreValueId === "string" ? req.query.coreValueId.trim() : "";
    const category = typeof req.query.category === "string" ? req.query.category.trim() : "";
    const limit = typeof req.query.limit === "string" ? Number(req.query.limit) : 12;
    if (!coreValueId) return res.status(400).json({ ok: false, error: "missing_coreValueId" });
    if (!category) return res.status(400).json({ ok: false, error: "missing_category" });
    const categoryKey = normalizeCategoryKey(category);
    const images = await listStockCategoryImagesPg({ coreValueId, categoryKey, limit });
    return res.json({
      ok: true,
      status: images.length ? "hit" : "miss",
      coreValueId,
      categoryKey,
      categoryLabel: category,
      images: images.map((i) => ({
        id: i.id,
        url: i.imageUrl,
        alt: i.alt,
        photographer: i.photographer,
        categoryLabel: i.categoryLabel,
      })),
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: "stock_category_images_failed", message: String(e?.message ?? e) });
  }
});

// ---- Wizard defaults + recommendations (public) ----
app.get("/wizard/defaults", async (req, res) => {
  try {
    const stored = await getWizardDefaults();
    const defaults = stored?.defaults && typeof stored.defaults === "object" ? stored.defaults : defaultWizardDefaults();
    res.json({
      ok: true,
      defaults,
      updatedAt: stored?.updatedAt ?? null,
    });
  } catch (e) {
    res.status(500).json({ error: "wizard_defaults_failed", message: String(e?.message ?? e) });
  }
});

app.get("/wizard/recommendations", async (req, res) => {
  try {
    const coreValueId = typeof req.query.coreValueId === "string" ? req.query.coreValueId.trim() : "";
    const category = typeof req.query.category === "string" ? req.query.category : "";
    const gender = typeof req.query.gender === "string" ? req.query.gender : "";
    if (!coreValueId) return res.status(400).json({ error: "missing_coreValueId" });
    if (!String(category).trim()) return res.status(400).json({ error: "missing_category" });

    const categoryKey = normalizeCategoryKey(category);
    const genderKey = normalizeGenderKey(gender);
    const wantsGender = genderKey === "male" || genderKey === "female" || genderKey === "non_binary";
    const unisexLimit = wantsGender ? 2 : 5;

    const [uni, gen] = await Promise.all([
      getWizardRecommendations({ coreValueId, categoryKey, genderKey: "unisex" }),
      wantsGender ? getWizardRecommendations({ coreValueId, categoryKey, genderKey }) : Promise.resolve(null),
    ]);

    const uniGoals = Array.isArray(uni?.recommendations?.goals) ? uni.recommendations.goals.slice(0, unisexLimit) : [];
    const genGoals = Array.isArray(gen?.recommendations?.goals) ? gen.recommendations.goals.slice(0, 3) : [];
    const merged = [...uniGoals, ...genGoals];
    if (!merged.length) return res.json({ ok: true, status: "miss", coreValueId, categoryKey, genderKey });

    const updatedAt = gen?.updatedAt ?? uni?.updatedAt ?? null;
    const source = gen?.source ?? uni?.source ?? null;
    const categoryLabel = gen?.categoryLabel ?? uni?.categoryLabel ?? category;
    return res.json({
      ok: true,
      status: "hit",
      coreValueId,
      categoryKey,
      genderKey,
      categoryLabel,
      recommendations: { goals: merged },
      updatedAt,
      source,
    });
  } catch (e) {
    res.status(500).json({ error: "wizard_recommendations_failed", message: String(e?.message ?? e) });
  }
});

app.post("/wizard/recommendations/generate", async (req, res) => {
  try {
    const coreValueId = typeof req.body?.coreValueId === "string" ? req.body.coreValueId.trim() : "";
    const category = typeof req.body?.category === "string" ? req.body.category : "";
    const gender = typeof req.body?.gender === "string" ? req.body.gender : "";
    if (!coreValueId) return res.status(400).json({ error: "missing_coreValueId" });
    if (!String(category).trim()) return res.status(400).json({ error: "missing_category" });

    const categoryKey = normalizeCategoryKey(category);
    const genderKey = normalizeGenderKey(gender);
    const wantsGender = genderKey === "male" || genderKey === "female" || genderKey === "non_binary";

    const [existingUni, existingGen] = await Promise.all([
      getWizardRecommendations({ coreValueId, categoryKey, genderKey: "unisex" }),
      wantsGender ? getWizardRecommendations({ coreValueId, categoryKey, genderKey }) : Promise.resolve(null),
    ]);

    if (existingUni?.recommendations && (!wantsGender || existingGen?.recommendations)) {
      // Fully satisfied.
      const uniGoals = Array.isArray(existingUni.recommendations?.goals) ? existingUni.recommendations.goals.slice(0, wantsGender ? 2 : 5) : [];
      const genGoals = wantsGender && Array.isArray(existingGen?.recommendations?.goals) ? existingGen.recommendations.goals.slice(0, 3) : [];
      const merged = [...uniGoals, ...genGoals];
      return res.json({
        ok: true,
        status: "hit",
        coreValueId,
        categoryKey,
        genderKey,
        categoryLabel: existingGen?.categoryLabel ?? existingUni.categoryLabel ?? category,
        recommendations: { goals: merged },
        updatedAt: existingGen?.updatedAt ?? existingUni?.updatedAt ?? null,
        source: existingGen?.source ?? existingUni?.source ?? null,
      });
    }

    const defaultsRec = await getWizardDefaults();
    const defaults = defaultsRec?.defaults && typeof defaultsRec.defaults === "object" ? defaultsRec.defaults : defaultWizardDefaults();
    const coreLabel =
      Array.isArray(defaults?.coreValues)
        ? defaults.coreValues.find((c) => c?.id === coreValueId)?.label ?? coreValueId
        : coreValueId;

    let createdAny = false;

    // Ensure unisex cache exists (5 goals; later we slice to 2 for gendered).
    let unisexRec = existingUni?.recommendations ? existingUni : null;
    if (!unisexRec?.recommendations) {
      const recommendations = await generateWizardRecommendationsWithGemini({
        coreValueId,
        coreValueLabel: coreLabel,
        category: String(category).trim(),
        goalsPerCategory: 5,
        habitsPerGoal: 3,
        audienceGender: "unisex",
      });
      await upsertWizardRecommendations({
        coreValueId,
        categoryKey,
        genderKey: "unisex",
        categoryLabel: String(category).trim(),
        recommendations,
        source: "gemini",
        createdBy: null,
      });
      unisexRec = { categoryLabel: String(category).trim(), recommendations, source: "gemini", updatedAt: new Date().toISOString() };
      createdAny = true;
    }

    let genderRec = existingGen?.recommendations ? existingGen : null;
    if (wantsGender && !genderRec?.recommendations) {
      const recommendations = await generateWizardRecommendationsWithGemini({
        coreValueId,
        coreValueLabel: coreLabel,
        category: String(category).trim(),
        goalsPerCategory: 3,
        habitsPerGoal: 3,
        audienceGender: genderKey,
      });
      await upsertWizardRecommendations({
        coreValueId,
        categoryKey,
        genderKey,
        categoryLabel: String(category).trim(),
        recommendations,
        source: "gemini",
        createdBy: null,
      });
      genderRec = { categoryLabel: String(category).trim(), recommendations, source: "gemini", updatedAt: new Date().toISOString() };
      createdAny = true;
    }

    const uniGoals = Array.isArray(unisexRec?.recommendations?.goals) ? unisexRec.recommendations.goals.slice(0, wantsGender ? 2 : 5) : [];
    const genGoals = wantsGender && Array.isArray(genderRec?.recommendations?.goals) ? genderRec.recommendations.goals.slice(0, 3) : [];
    const merged = [...uniGoals, ...genGoals];

    return res.json({
      ok: true,
      status: createdAny ? "generated" : "hit",
      coreValueId,
      categoryKey,
      genderKey,
      categoryLabel: (wantsGender ? genderRec?.categoryLabel : null) ?? unisexRec?.categoryLabel ?? String(category).trim(),
      recommendations: { goals: merged },
    });
  } catch (e) {
    res.status(500).json({ error: "wizard_generate_failed", message: String(e?.message ?? e) });
  }
});

// ---- Wizard sync/reset (admin) ----
app.post("/admin/wizard/sync-defaults", requireAdmin(), async (req, res) => {
  try {
    // Back-compat endpoint.
    // If called directly, start an async job by default to avoid client timeouts.
    const asyncDefault = String(process.env.WIZARD_SYNC_ASYNC_DEFAULT ?? "true").trim().toLowerCase() !== "false";
    const wantsSync = String(req.query.wait ?? "").trim().toLowerCase() === "true";
    if (asyncDefault && !wantsSync) {
      // Delegate to start endpoint semantics.
      const reset = Boolean(req.body?.reset);
      const createdBy = req.dvUser?.canvaUserId ?? null;
      const jobId = `wjob_${randomId(12)}`;
      const job = {
        jobId,
        reset,
        createdBy,
        running: true,
        startedAt: new Date().toISOString(),
        finishedAt: null,
        total: 0,
        succeeded: 0,
        skipped: 0,
        failed: 0,
        sampleErrors: [],
      };
      wizardSyncJobs.set(jobId, job);
      // Fire and forget.
      (async () => {
        try {
          const result = await runWizardSyncDefaultsJob({ reset, createdBy, job });
          Object.assign(job, result, { running: false, finishedAt: new Date().toISOString() });
        } catch (e) {
          job.running = false;
          job.finishedAt = new Date().toISOString();
          job.failed = job.failed ?? 0;
          job.sampleErrors = [...(job.sampleErrors ?? []), String(e?.message ?? e)].slice(0, 5);
        }
      })();

      return res.status(202).json({
        ok: true,
        async: true,
        jobId,
        statusUrl: `/admin/wizard/sync-defaults/status?jobId=${encodeURIComponent(jobId)}`,
      });
    }

    const reset = Boolean(req.body?.reset);
    const defaults = defaultWizardDefaults();
    // Always re-write defaults (idempotent).
    await putWizardDefaults({ defaults });

    const categoriesByCore = defaults.categoriesByCoreValueId ?? {};
    const createdBy = req.dvUser?.canvaUserId ?? null;

    const result = await runWizardSyncDefaultsJob({ reset, createdBy, job: null });

    res.json({
      ok: true,
      reset,
      seeded: result.total,
      succeeded: result.succeeded,
      skipped: result.skipped,
      failed: result.failed,
      sampleErrors: result.sampleErrors,
    });
  } catch (e) {
    res.status(500).json({ error: "wizard_sync_failed", message: String(e?.message ?? e) });
  }
});

// ---- Stock category images sync (admin) ----
app.post("/admin/stock/sync-category-images/start", requireAdmin(), async (req, res) => {
  if (!ensureDbOr501(res)) return;
  const perCategory = typeof req.body?.perCategory === "number" ? Math.trunc(req.body.perCategory) : 12;
  const pp = Math.max(1, Math.min(30, perCategory));
  const jobId = `simg_${randomId(12)}`;
  const job = {
    jobId,
    perCategory: pp,
    running: true,
    startedAt: new Date().toISOString(),
    finishedAt: null,
    total: 0,
    succeeded: 0,
    skipped: 0,
    failed: 0,
    sampleErrors: [],
  };
  stockImagesSyncJobs.set(jobId, job);

  (async () => {
    try {
      const result = await runStockCategoryImagesSyncJob({ perCategory: pp, job });
      Object.assign(job, result, { running: false, finishedAt: new Date().toISOString() });
    } catch (e) {
      job.running = false;
      job.finishedAt = new Date().toISOString();
      job.failed = job.failed ?? 0;
      job.sampleErrors = [...(job.sampleErrors ?? []), String(e?.message ?? e)].slice(0, 5);
    }
  })();

  res.status(202).json({
    ok: true,
    async: true,
    jobId,
    statusUrl: `/admin/stock/sync-category-images/status?jobId=${encodeURIComponent(jobId)}`,
  });
});

app.get("/admin/stock/sync-category-images/status", requireAdmin(), async (req, res) => {
  const jobId = typeof req.query.jobId === "string" ? req.query.jobId.trim() : "";
  if (!jobId) return res.status(400).json({ error: "missing_jobId" });
  const job = stockImagesSyncJobs.get(jobId);
  if (!job) return res.status(404).json({ error: "job_not_found" });
  res.json({ ok: true, job });
});

async function runStockCategoryImagesSyncJob({ perCategory, job }) {
  const defaults = defaultWizardDefaults();
  const categoriesByCore = defaults.categoriesByCoreValueId ?? {};

  const tasks = [];
  for (const coreValueId of Object.keys(categoriesByCore)) {
    const coreLabel = defaultWizardCoreLabel(coreValueId);
    const cats = Array.isArray(categoriesByCore[coreValueId]) ? categoriesByCore[coreValueId] : [];
    for (const cat of cats) {
      const categoryLabel = String(cat ?? "").trim();
      if (!categoryLabel) continue;
      tasks.push({ coreValueId, coreLabel, categoryLabel, categoryKey: normalizeCategoryKey(categoryLabel) });
    }
  }
  if (job) job.total = tasks.length;

  let succeeded = 0;
  let skipped = 0;
  let failed = 0;
  const sampleErrors = [];

  for (const t of tasks) {
    try {
      const query = buildStockQuery({ coreValueLabel: t.coreLabel, categoryLabel: t.categoryLabel });
      const result = await searchPexelsPhotos({ query, perPage: Math.max(1, Math.min(30, perCategory)) });
      if (!result.ok) throw new Error(result.error ?? "pexels_search_failed");
      const photos = Array.isArray(result.photos) ? result.photos : [];
      if (!photos.length) {
        skipped++;
        if (job) job.skipped = skipped;
        continue;
      }
      for (const p of photos) {
        const pexelsId = p?.id ?? null;
        const url = p?.src?.large ?? p?.src?.medium ?? p?.src?.original ?? p?.src?.small ?? null;
        if (!url) continue;
        const id = `pimg_${t.coreValueId}_${t.categoryKey}_${String(pexelsId ?? randomId(10))}`.slice(0, 80);
        await upsertStockCategoryImagePg({
          id,
          coreValueId: t.coreValueId,
          categoryKey: t.categoryKey,
          categoryLabel: t.categoryLabel,
          pexelsPhotoId: pexelsId,
          query,
          imageUrl: url,
          alt: p?.alt ?? "",
          photographer: p?.photographer ?? "",
        });
      }
      succeeded++;
      if (job) job.succeeded = succeeded;
    } catch (e) {
      failed++;
      const err = String(e?.message ?? e);
      if (sampleErrors.length < 5) sampleErrors.push(`${t.categoryLabel}: ${err}`);
      if (job) {
        job.failed = failed;
        job.sampleErrors = sampleErrors;
      }
    }
  }

  return { total: tasks.length, succeeded, skipped, failed, sampleErrors };
}

app.post("/admin/wizard/sync-defaults/start", requireAdmin(), async (req, res) => {
  const reset = Boolean(req.body?.reset);
  const createdBy = req.dvUser?.canvaUserId ?? null;
  const jobId = `wjob_${randomId(12)}`;
  const job = {
    jobId,
    reset,
    createdBy,
    running: true,
    startedAt: new Date().toISOString(),
    finishedAt: null,
    total: 0,
    succeeded: 0,
    skipped: 0,
    failed: 0,
    sampleErrors: [],
  };
  wizardSyncJobs.set(jobId, job);

  (async () => {
    try {
      const result = await runWizardSyncDefaultsJob({ reset, createdBy, job });
      Object.assign(job, result, { running: false, finishedAt: new Date().toISOString() });
    } catch (e) {
      job.running = false;
      job.finishedAt = new Date().toISOString();
      job.failed = job.failed ?? 0;
      job.sampleErrors = [...(job.sampleErrors ?? []), String(e?.message ?? e)].slice(0, 5);
    }
  })();

  res.status(202).json({
    ok: true,
    async: true,
    jobId,
    statusUrl: `/admin/wizard/sync-defaults/status?jobId=${encodeURIComponent(jobId)}`,
  });
});

app.get("/admin/wizard/sync-defaults/status", requireAdmin(), async (req, res) => {
  const jobId = typeof req.query.jobId === "string" ? req.query.jobId.trim() : "";
  if (!jobId) return res.status(400).json({ error: "missing_jobId" });
  const job = wizardSyncJobs.get(jobId);
  if (!job) return res.status(404).json({ error: "job_not_found" });
  res.json({ ok: true, job });
});

async function runWizardSyncDefaultsJob({ reset, createdBy, job }) {
  const defaults = defaultWizardDefaults();
  await putWizardDefaults({ defaults });

  const categoriesByCore = defaults.categoriesByCoreValueId ?? {};

  // Build task list (for progress counts)
  const tasks = [];
  for (const coreValueId of Object.keys(categoriesByCore)) {
    const cats = Array.isArray(categoriesByCore[coreValueId]) ? categoriesByCore[coreValueId] : [];
    for (const cat of cats) {
      const category = String(cat ?? "").trim();
      if (!category) continue;
      tasks.push({ coreValueId, category, categoryKey: normalizeCategoryKey(category) });
    }
  }
  if (job) job.total = tasks.length;

  let succeeded = 0;
  let skipped = 0;
  let failed = 0;
  const sampleErrors = [];

  // Batch by core value to reduce Gemini requests (fits free-tier daily quotas).
  for (const coreValueId of Object.keys(categoriesByCore)) {
    const coreLabel = defaults.coreValues.find((c) => c.id === coreValueId)?.label ?? coreValueId;
    const catsRaw = Array.isArray(categoriesByCore[coreValueId]) ? categoriesByCore[coreValueId] : [];
    const cats = catsRaw.map((c) => String(c ?? "").trim()).filter(Boolean);
    if (cats.length === 0) continue;

    // If not reset, filter to only missing categories (reduces calls further).
    let toGenerate = cats;
    if (!reset) {
      const missing = [];
      for (const category of cats) {
        const categoryKey = normalizeCategoryKey(category);
        const existing = await getWizardRecommendations({ coreValueId, categoryKey, genderKey: "unisex" });
        if (existing?.recommendations) {
          skipped++;
          if (job) job.skipped = skipped;
        } else {
          missing.push(category);
        }
      }
      toGenerate = missing;
    }
    if (toGenerate.length === 0) continue;

    try {
      const batch = await generateWizardRecommendationsBatchWithGemini({
        coreValueId,
        coreValueLabel: coreLabel,
        categories: toGenerate,
        goalsPerCategory: 5,
        habitsPerGoal: 3,
        maxCategoriesPerCall: Number(process.env.WIZARD_BATCH_MAX_CATEGORIES ?? 6),
      });

      for (const category of toGenerate) {
        const found = batch[category] ?? batch[String(category).toLowerCase()] ?? null;
        if (!found?.goals || !Array.isArray(found.goals) || found.goals.length < 5) {
          // Fallback to single-category generation for this category.
          try {
            const recommendations = await generateWizardRecommendationsWithGemini({
              coreValueId,
              coreValueLabel: coreLabel,
              category,
              goalsPerCategory: 5,
              habitsPerGoal: 3,
              audienceGender: "unisex",
            });
            await upsertWizardRecommendations({
              coreValueId,
              categoryKey: normalizeCategoryKey(category),
              genderKey: "unisex",
              categoryLabel: category,
              recommendations,
              source: "gemini",
              createdBy,
            });
            succeeded++;
            if (job) job.succeeded = succeeded;
          } catch (e) {
            failed++;
            const err = String(e?.message ?? e);
            if (sampleErrors.length < 3) sampleErrors.push(err);
            if (job) {
              job.failed = failed;
              job.sampleErrors = sampleErrors;
            }
          }
          continue;
        }

        await upsertWizardRecommendations({
          coreValueId,
          categoryKey: normalizeCategoryKey(category),
          genderKey: "unisex",
          categoryLabel: category,
          recommendations: { goals: found.goals },
          source: "gemini",
          createdBy,
        });
        succeeded++;
        if (job) job.succeeded = succeeded;
      }
    } catch (e) {
      // If a whole batch fails (quota, parse, etc), mark each category as failed but keep going.
      for (let i = 0; i < toGenerate.length; i++) {
        failed++;
        const err = String(e?.message ?? e);
        if (sampleErrors.length < 3) sampleErrors.push(err);
        if (job) {
          job.failed = failed;
          job.sampleErrors = sampleErrors;
        }
      }
    }
  }

  return { total: tasks.length, succeeded, skipped, failed, sampleErrors };
}

/**
 * Guest auth (no Canva required).
 * Returns a backend-issued dvToken that expires in 10 days.
 *
 * Body (optional):
 * - home_timezone: IANA timezone string (e.g. "America/Los_Angeles")
 * - gender: 'male' | 'female' | 'non_binary' | 'prefer_not_to_say'
 */
app.post("/auth/guest", async (req, res) => {
  try {
    const homeTimezone = typeof req.body?.home_timezone === "string" ? req.body.home_timezone : null;
    const gender = typeof req.body?.gender === "string" ? req.body.gender.trim() : "prefer_not_to_say";
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

    if (hasDatabase()) {
      await putUserSettingsPg(guestId, { homeTimezone, gender: gender || "prefer_not_to_say" });
    }

    res.json({
      ok: true,
      dvToken,
      expiresAt: new Date(expiresAtMs).toISOString(),
      home_timezone: homeTimezone,
      gender: gender || "prefer_not_to_say",
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

function maybeRotationRad(x) {
  if (typeof x !== "number" || !Number.isFinite(x)) return 0;
  // Canva element rotation is often in degrees; Flutter uses radians.
  // Heuristic: if magnitude is larger than ~2π, treat as degrees.
  const abs = Math.abs(x);
  if (abs > 2 * Math.PI + 0.01) return (x * Math.PI) / 180;
  return x;
}

function parseArgbColor(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    // Assume already ARGB int.
    return value | 0;
  }
  if (typeof value === "string") {
    const s = value.trim().toLowerCase();
    // Accept "#RRGGBB" or "#AARRGGBB"
    if (s.startsWith("#") && (s.length === 7 || s.length === 9)) {
      const hex = s.slice(1);
      const n = Number.parseInt(hex, 16);
      if (!Number.isFinite(n)) return null;
      if (hex.length === 6) return (0xff000000 | n) | 0;
      return n | 0;
    }
  }
  // Accept { r,g,b,a } in 0..1 or 0..255
  if (value && typeof value === "object") {
    const r = value.r ?? value.red;
    const g = value.g ?? value.green;
    const b = value.b ?? value.blue;
    const a = value.a ?? value.alpha;
    const nums = [r, g, b].every((v) => typeof v === "number" && Number.isFinite(v));
    if (!nums) return null;
    const isFrac = Math.max(Math.abs(r), Math.abs(g), Math.abs(b), typeof a === "number" ? Math.abs(a) : 1) <= 1.5;
    const rr = Math.max(0, Math.min(255, Math.round(isFrac ? r * 255 : r)));
    const gg = Math.max(0, Math.min(255, Math.round(isFrac ? g * 255 : g)));
    const bb = Math.max(0, Math.min(255, Math.round(isFrac ? b * 255 : b)));
    const aa =
      typeof a === "number" && Number.isFinite(a)
        ? Math.max(0, Math.min(255, Math.round(isFrac ? a * 255 : a)))
        : 255;
    return (((aa & 0xff) << 24) | ((rr & 0xff) << 16) | ((gg & 0xff) << 8) | (bb & 0xff)) | 0;
  }
  return null;
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

      const rawText = typeof e.text === "string" ? e.text.trim() : "";
      const typeStr = typeof e.type === "string" ? e.type.toLowerCase() : "";
      const isText = Boolean(rawText) || typeStr.includes("text");

      if (isText) {
        const rotationRad = maybeRotationRad(e.rotation);

        // Best-effort TextStyle (Flutter expects a map with these keys).
        const styleSrc = (e.style && typeof e.style === "object" ? e.style : e) ?? {};
        const color = parseArgbColor(styleSrc.color ?? styleSrc.textColor ?? styleSrc.fillColor);
        const fontSize =
          typeof styleSrc.fontSize === "number" && Number.isFinite(styleSrc.fontSize) ? styleSrc.fontSize : null;
        const fontFamily = typeof styleSrc.fontFamily === "string" ? styleSrc.fontFamily : null;
        const fontWeight =
          typeof styleSrc.fontWeight === "number" && Number.isFinite(styleSrc.fontWeight)
            ? Math.max(0, Math.min(8, Math.round(styleSrc.fontWeight)))
            : null;
        const fontStyle =
          typeof styleSrc.fontStyle === "number" && Number.isFinite(styleSrc.fontStyle)
            ? Math.max(0, Math.min(1, Math.round(styleSrc.fontStyle)))
            : null;

        // Flutter TextAlign index: left=0,right=1,center=2,justify=3,start=4,end=5
        let textAlign = 0;
        const ta = styleSrc.textAlign ?? styleSrc.align;
        if (typeof ta === "number" && Number.isFinite(ta)) {
          textAlign = Math.max(0, Math.min(5, Math.round(ta)));
        } else if (typeof ta === "string") {
          const s = ta.toLowerCase();
          if (s === "right") textAlign = 1;
          else if (s === "center") textAlign = 2;
          else if (s === "justify") textAlign = 3;
          else if (s === "start") textAlign = 4;
          else if (s === "end") textAlign = 5;
          else textAlign = 0;
        }

        const style = {};
        if (color != null) style.color = color;
        if (fontSize != null) style.fontSize = fontSize;
        if (fontFamily) style.fontFamily = fontFamily;
        if (fontWeight != null) style.fontWeight = fontWeight;
        if (fontStyle != null) style.fontStyle = fontStyle;

        components.push({
          type: "text",
          id: `canva_text_${randomId(10)}`,
          position: { dx: rect.left, dy: rect.top },
          size: { w: rect.width, h: rect.height },
          rotation: rotationRad,
          scale: 1,
          zIndex: z++,
          habits: [],
          tasks: [],
          isDisabled: false,
          text: rawText || `Text ${i + 1}`,
          style,
          textAlign,
        });
        continue;
      }

      // Note: rotation is ignored for image crops (axis-aligned crop).
      const croppedPng = await sharp(pngBytes).extract(rect).png().toBuffer();
      const imageId = `timg_${randomId(16)}`;
      await insertTemplateImagePg({
        id: imageId,
        createdBy,
        contentType: "image/png",
        bytes: croppedPng,
      });

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
        templateJson: { canvasSize: { w: imgW, h: imgH }, components },
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
  const gender = typeof req.body?.gender === "string" ? req.body.gender.trim() : "prefer_not_to_say";
  await putUserSettingsPg(req.dvUser.canvaUserId, { homeTimezone, gender: gender || "prefer_not_to_say" });
  res.json({ ok: true, home_timezone: homeTimezone, gender: gender || "prefer_not_to_say" });
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
    gender: settings?.gender ?? "prefer_not_to_say",
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
 *   userSettings?: { homeTimezone, gender },
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

