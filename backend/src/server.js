import "dotenv/config";
import express from "express";
import cors from "cors";

import { randomId } from "./crypto.js";
import { admin, ensureFirebaseAdmin } from "./firebase_admin.js";
import {
  getUserRecord,
  putUserRecord,
} from "./storage.js";
import { requireDvAuth } from "./auth.js";
import {
  getWizardDefaults,
  getWizardRecommendations,
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
  getTemplateImagePg,
  getTemplatePg,
  listTemplatesPg,
} from "./templates_pg.js";
import { generateWizardRecommendationsWithGemini } from "./gemini.js";
import { searchPexelsPhotos } from "./pexels.js";
import { listStockCategoryImagesPg } from "./stock_category_images_pg.js";
import {
  getAllAffirmationsPg,
  getAffirmationsPg,
  upsertAffirmationPg,
  deleteAffirmationPg,
  pinAffirmationPg,
} from "./affirmations_pg.js";

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
        "- GET /privacy-policy",
        "- GET /templates",
      ].join("\n"),
    );
});

app.get("/health", (req, res) => res.json({ ok: true }));

// ---- Privacy Policy ----
app.get("/privacy-policy", (req, res) => {
  res.setHeader("content-type", "text/html; charset=utf-8");
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Privacy Policy - Digital Vision Board</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
      background: #f5f5f5;
    }
    .container {
      background: white;
      padding: 40px;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    h1 { color: #6366f1; margin-top: 0; }
    h2 { color: #4f46e5; margin-top: 2rem; border-bottom: 2px solid #e5e7eb; padding-bottom: 0.5rem; }
    h3 { color: #6366f1; margin-top: 1.5rem; }
    h4 { color: #6b7280; margin-top: 1rem; }
    ul { padding-left: 1.5rem; }
    li { margin: 0.5rem 0; }
    .last-updated { color: #6b7280; font-size: 0.9rem; margin-top: 2rem; }
    a { color: #6366f1; text-decoration: none; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Privacy Policy</h1>
    <p><strong>Last Updated:</strong> January 2025</p>

    <h2>Your Privacy Matters</h2>
    <p>
      Digital Vision Board is committed to protecting your privacy. This policy
      explains how we collect, use, and safeguard your personal information.
    </p>

    <h2>Data Collection</h2>
    <p>
      Digital Vision Board is a local-first application. Most of your data is
      stored directly on your device:
    </p>
    <ul>
      <li>
        <strong>Goals, Habits, and Tasks:</strong> All goal definitions, habit
        tracking data, task checklists, and completion feedback are stored
        locally on your device.
      </li>
      <li>
        <strong>Vision Board Content:</strong> Images, board layouts, and
        customizations are stored on your device. Images may be downloaded
        from external sources (like Pexels) but are cached locally.
      </li>
      <li>
        <strong>Progress Data:</strong> Completion dates, streaks, activity
        summaries, and insights are calculated and stored locally.
      </li>
    </ul>

    <h2>Optional Data Collection</h2>
    <p>
      Some features require additional permissions and data collection:
    </p>
    <ul>
      <li>
        <strong>Location Data:</strong> If you enable location-based habit
        tracking (geofencing), the app will access your device location to
        trigger habits when you enter specified areas. Location data is used
        only for geofencing and is not stored permanently.
      </li>
      <li>
        <strong>Camera and Storage:</strong> To scan physical boards or import
        images, the app requests camera and storage permissions. Images are
        stored locally on your device. Camera access is only used when you
        explicitly choose to take a photo.
      </li>
    </ul>

    <h2>Authentication</h2>
    <p>
      Digital Vision Board supports multiple authentication methods:
    </p>
    <ul>
      <li>
        <strong>Google Sign-In:</strong> If you choose to sign in with Google,
        your Google account information is used for authentication only. We
        do not access your Google account data beyond authentication.
      </li>
      <li>
        <strong>Phone Authentication:</strong> Phone number authentication
        is handled securely through Firebase Authentication.
      </li>
      <li>
        <strong>Guest Mode:</strong> You can use the app without creating an
        account. All data remains local to your device.
      </li>
    </ul>

    <h2>Local-First Storage</h2>
    <p>
      By default, all your data is stored locally on your device using
      platform-specific storage (SharedPreferences on Android/iOS). This means:
    </p>
    <ul>
      <li>Your data is private to your device</li>
      <li>No data is sent to external servers unless you explicitly enable cloud sync</li>
      <li>You have full control over your data</li>
    </ul>

    <h2>Optional Cloud Sync</h2>
    <p>
      If you choose to enable Firebase Cloud Sync (optional feature):
    </p>
    <ul>
      <li>Your data will be synchronized to Firebase servers</li>
      <li>Data is encrypted in transit and at rest</li>
      <li>You can disable cloud sync at any time</li>
      <li>Cloud sync requires Firebase configuration files</li>
    </ul>

    <h2>Third-Party Services</h2>
    <p>
      Digital Vision Board may integrate with the following third-party services:
    </p>
    <ul>
      <li>
        <strong>Pexels:</strong> Image search functionality may query Pexels
        API for stock images. Search terms are sent to Pexels; no user data
        is shared.
      </li>
      <li>
        <strong>Firebase:</strong> Optional cloud storage and authentication.
        Firebase's privacy policy applies when cloud sync is enabled.
      </li>
    </ul>

    <h2>Permissions</h2>
    <p>
      Digital Vision Board requests the following permissions:
    </p>
    <ul>
      <li>
        <strong>Location:</strong> For geofencing-based habit tracking
        (ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION, ACCESS_BACKGROUND_LOCATION)
      </li>
      <li>
        <strong>Storage/Media:</strong> For importing images, scanning boards,
        and accessing media files (READ_EXTERNAL_STORAGE, READ_MEDIA_AUDIO)
      </li>
      <li>
        <strong>Notifications:</strong> For habit reminders and progress updates
        (POST_NOTIFICATIONS)
      </li>
      <li>
        <strong>Camera:</strong> For scanning physical boards and taking photos.
        Camera access is only requested when you choose to take a photo, not
        automatically. Photos are stored locally on your device and are not
        shared with third parties.
      </li>
    </ul>
    <p>
      All permissions are optional and only requested when relevant features
      are used. You can deny any permission and still use core app features.
    </p>

    <h2>Data Security</h2>
    <p>
      We take data security seriously:
    </p>
    <ul>
      <li>Local data is stored using platform-secured storage mechanisms</li>
      <li>Cloud data (if enabled) is encrypted in transit using TLS and at rest using Firebase encryption</li>
      <li>OAuth tokens are stored securely using platform keychains</li>
      <li>No data is shared with third parties except as described in this policy</li>
    </ul>

    <h2>Your Rights</h2>
    <p>
      You have the right to:
    </p>
    <ul>
      <li>
        <strong>Access Your Data:</strong> All data is stored locally and
        accessible through the app. If cloud sync is enabled, you can access
        data through Firebase.
      </li>
      <li>
        <strong>Delete Your Data:</strong> You can delete individual goals,
        habits, tasks, or entire boards at any time through the app interface.
      </li>
      <li>
        <strong>Export Your Data:</strong> Data is stored in JSON format and
        can be accessed through device file managers (advanced users).
      </li>
      <li>
        <strong>Disable Permissions:</strong> You can revoke any permission
        through your device settings. Some features may be limited if permissions
        are disabled.
      </li>
      <li>
        <strong>Delete Your Account:</strong> If you created an account, you
        can delete it through the app settings or by contacting support.
      </li>
    </ul>

    <h2>Children's Privacy</h2>
    <p>
      Digital Vision Board is not intended for children under 13 years of age.
      We do not knowingly collect personal information from children under 13.
      If you are a parent or guardian and believe your child has provided us
      with personal information, please contact us to have that information
      removed.
    </p>

    <h2>Changes to This Policy</h2>
    <p>
      We may update this Privacy Policy from time to time. We will notify you
      of any changes by posting the new Privacy Policy on this page and updating
      the "Last updated" date. You are advised to review this Privacy Policy
      periodically for any changes.
    </p>

    <h2>Contact Us</h2>
    <p>
      If you have any questions about this Privacy Policy or our data practices,
      please contact us through the app settings or visit our support page.
    </p>

    <p class="last-updated">
      <strong>Last Updated:</strong> January 2025
    </p>
  </div>
</body>
</html>`);
});

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





/**
 * Guest auth.
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
 * Exchange a Firebase Auth ID token for a dvToken used by this backend.
 * Body: { idToken: string }
 */
app.post("/auth/firebase/exchange", async (req, res) => {
  try {
    const idToken = typeof req.body?.idToken === "string" ? req.body.idToken.trim() : "";
    if (!idToken) return res.status(400).json({ ok: false, error: "missing_idToken" });

    ensureFirebaseAdmin();
    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = typeof decoded?.uid === "string" ? decoded.uid : null;
    if (!uid) return res.status(401).json({ ok: false, error: "invalid_firebase_token" });

    const userId = `fb_${uid}`;
    const existing = (await getUserRecord(userId)) ?? null;
    const dvToken = existing?.dvToken ?? randomId(24);

    const record = {
      ...(existing && typeof existing === "object" ? existing : {}),
      canvaUserId: userId,
      teamId: null,
      dvToken,
      isGuest: false,
      guestExpiresAtMs: null,
      firebase: {
        uid,
        signInProvider: decoded?.firebase?.sign_in_provider ?? null,
        email: decoded?.email ?? null,
        phoneNumber: decoded?.phone_number ?? null,
      },
    };

    await putUserRecord(userId, record);

    return res.json({ ok: true, dvToken, userId });
  } catch (e) {
    const msg = String(e?.message ?? e);
    // Common misconfig: firebase-admin not configured.
    return res.status(500).json({ ok: false, error: "firebase_exchange_failed", message: msg });
  }
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
  const displayName = typeof req.body?.display_name === "string" ? req.body.display_name.trim() || null : null;
  const weightKg = typeof req.body?.weight_kg === "number" && !Number.isNaN(req.body.weight_kg) ? req.body.weight_kg : (typeof req.body?.weight_kg === "string" ? parseFloat(req.body.weight_kg) : null);
  const heightCm = typeof req.body?.height_cm === "number" && !Number.isNaN(req.body.height_cm) ? req.body.height_cm : (typeof req.body?.height_cm === "string" ? parseFloat(req.body.height_cm) : null);
  const weightKgVal = typeof weightKg === "number" && !Number.isNaN(weightKg) ? weightKg : null;
  const heightCmVal = typeof heightCm === "number" && !Number.isNaN(heightCm) ? heightCm : null;
  const dateOfBirth = typeof req.body?.date_of_birth === "string" && /^\d{4}-\d{2}-\d{2}$/.test(req.body.date_of_birth) ? req.body.date_of_birth : null;
  await putUserSettingsPg(req.dvUser.canvaUserId, { homeTimezone, gender: gender || "prefer_not_to_say", displayName, weightKg: weightKgVal, heightCm: heightCmVal, dateOfBirth });
  res.json({ ok: true, home_timezone: homeTimezone, gender: gender || "prefer_not_to_say", display_name: displayName, weight_kg: weightKgVal, height_cm: heightCmVal, date_of_birth: dateOfBirth });
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
    display_name: settings?.displayName ?? null,
    weight_kg: settings?.weightKg ?? null,
    height_cm: settings?.heightCm ?? null,
    date_of_birth: settings?.dateOfBirth ?? null,
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

// ---- Affirmations APIs ----
app.get("/api/affirmations", requireDvAuth(), async (req, res) => {
  if (!hasDatabase()) return res.status(501).json({ error: "database_required" });
  try {
    const category = typeof req.query.category === "string" ? req.query.category.trim() : null;
    const affirmations = await getAffirmationsPg(req.dvUser.canvaUserId, category || null);
    res.json({ ok: true, affirmations });
  } catch (e) {
    res.status(500).json({ error: "affirmations_fetch_failed", message: String(e?.message ?? e) });
  }
});

app.post("/api/affirmations", requireDvAuth(), async (req, res) => {
  if (!hasDatabase()) return res.status(501).json({ error: "database_required" });
  try {
    const body = req.body ?? {};
    const affirmation = {
      id: typeof body.id === "string" ? body.id : null,
      category: typeof body.category === "string" ? body.category.trim() || null : null,
      text: typeof body.text === "string" ? body.text.trim() : "",
      isPinned: Boolean(body.is_pinned ?? body.isPinned ?? false),
      isCustom: Boolean(body.is_custom ?? body.isCustom ?? true),
    };
    if (!affirmation.text) {
      return res.status(400).json({ error: "text_required" });
    }
    const affirmationId = await upsertAffirmationPg(req.dvUser.canvaUserId, affirmation);
    res.json({ ok: true, id: affirmationId });
  } catch (e) {
    res.status(500).json({ error: "affirmation_create_failed", message: String(e?.message ?? e) });
  }
});

app.put("/api/affirmations/:id", requireDvAuth(), async (req, res) => {
  if (!hasDatabase()) return res.status(501).json({ error: "database_required" });
  try {
    const affirmationId = String(req.params.id ?? "").trim();
    if (!affirmationId) {
      return res.status(400).json({ error: "id_required" });
    }
    const body = req.body ?? {};
    const affirmation = {
      id: affirmationId,
      category: typeof body.category === "string" ? body.category.trim() || null : null,
      text: typeof body.text === "string" ? body.text.trim() : "",
      isPinned: Boolean(body.is_pinned ?? body.isPinned ?? false),
      isCustom: Boolean(body.is_custom ?? body.isCustom ?? true),
    };
    if (!affirmation.text) {
      return res.status(400).json({ error: "text_required" });
    }
    await upsertAffirmationPg(req.dvUser.canvaUserId, affirmation);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: "affirmation_update_failed", message: String(e?.message ?? e) });
  }
});

app.delete("/api/affirmations/:id", requireDvAuth(), async (req, res) => {
  if (!hasDatabase()) return res.status(501).json({ error: "database_required" });
  try {
    const affirmationId = String(req.params.id ?? "").trim();
    if (!affirmationId) {
      return res.status(400).json({ error: "id_required" });
    }
    const deleted = await deleteAffirmationPg(req.dvUser.canvaUserId, affirmationId);
    if (!deleted) {
      return res.status(404).json({ error: "affirmation_not_found" });
    }
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: "affirmation_delete_failed", message: String(e?.message ?? e) });
  }
});

app.put("/api/affirmations/:id/pin", requireDvAuth(), async (req, res) => {
  if (!hasDatabase()) return res.status(501).json({ error: "database_required" });
  try {
    const affirmationId = String(req.params.id ?? "").trim();
    if (!affirmationId) {
      return res.status(400).json({ error: "id_required" });
    }
    const body = req.body ?? {};
    const isPinned = Boolean(body.is_pinned ?? body.isPinned ?? true);
    const updated = await pinAffirmationPg(req.dvUser.canvaUserId, affirmationId, isPinned);
    if (!updated) {
      return res.status(404).json({ error: "affirmation_not_found" });
    }
    res.json({ ok: true, is_pinned: isPinned });
  } catch (e) {
    res.status(500).json({ error: "affirmation_pin_failed", message: String(e?.message ?? e) });
  }
});

// Export app for Vercel serverless functions
export default app;

// Only start listening if not in Vercel environment
if (process.env.VERCEL !== "1") {
  const port = Number(process.env.PORT ?? 8787);
  app.listen(port, () => {
    // eslint-disable-next-line no-console
    console.log(`Backend listening on http://localhost:${port}`);
  });
}

