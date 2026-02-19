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
  getUserSettingsPg,
  putUserSettingsPg,
  getEncryptionKeyPg,
  putEncryptionKeyPg,
} from "./sync_pg.js";
import {
  getTemplateImagePg,
  getTemplatePg,
  listTemplatesPg,
} from "./templates_pg.js";
import { generateWizardRecommendationsWithGemini } from "./gemini.js";
import { searchPexelsPhotos } from "./pexels.js";
import { listStockCategoryImagesPg } from "./stock_category_images_pg.js";
import { getGiftCodePg, redeemGiftCodePg } from "./gift_codes_pg.js";

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

// ---- User Settings + Encryption Key ----

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
  const subscriptionPlanId = typeof req.body?.subscription_plan_id === "string" ? req.body.subscription_plan_id.trim() || null : null;
  const subscriptionActive = req.body?.subscription_active != null ? Boolean(req.body.subscription_active) : null;
  const subscriptionSource = typeof req.body?.subscription_source === "string" ? req.body.subscription_source.trim() || null : null;
  await putUserSettingsPg(req.dvUser.canvaUserId, { homeTimezone, gender: gender || "prefer_not_to_say", displayName, weightKg: weightKgVal, heightCm: heightCmVal, dateOfBirth, subscriptionPlanId, subscriptionActive, subscriptionSource });
  res.json({ ok: true, home_timezone: homeTimezone, gender: gender || "prefer_not_to_say", display_name: displayName, weight_kg: weightKgVal, height_cm: heightCmVal, date_of_birth: dateOfBirth, subscription_plan_id: subscriptionPlanId, subscription_active: subscriptionActive, subscription_source: subscriptionSource });
});

app.get("/user/encryption-key", requireDvAuth(), async (req, res) => {
  if (!hasDatabase()) return res.status(501).json({ error: "database_required" });
  try {
    const key = await getEncryptionKeyPg(req.dvUser.canvaUserId);
    res.json({ ok: true, encryption_key: key });
  } catch (e) {
    res.status(500).json({ error: "encryption_key_fetch_failed", message: String(e?.message ?? e) });
  }
});

app.put("/user/encryption-key", requireDvAuth(), async (req, res) => {
  if (!hasDatabase()) return res.status(501).json({ error: "database_required" });
  try {
    const key = typeof req.body?.encryption_key === "string" ? req.body.encryption_key.trim() : null;
    if (!key) return res.status(400).json({ error: "missing_encryption_key" });
    await putEncryptionKeyPg(req.dvUser.canvaUserId, key);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: "encryption_key_update_failed", message: String(e?.message ?? e) });
  }
});

// ---- Gift Code Redemption ----

app.get("/gift-codes/validate", requireDvAuth(), async (req, res) => {
  if (!ensureDbOr501(res)) return;
  try {
    const code = typeof req.query.code === "string" ? req.query.code.trim().toUpperCase() : "";
    if (!code) return res.status(400).json({ ok: false, error: "missing_code" });

    const gc = await getGiftCodePg(code);
    if (!gc) return res.json({ ok: true, valid: false, error: "invalid_code" });
    if (!gc.active) return res.json({ ok: true, valid: false, error: "code_inactive" });
    if (gc.usedCount >= gc.maxUses) return res.json({ ok: true, valid: false, error: "code_exhausted" });

    return res.json({
      ok: true,
      valid: true,
      plan_id: gc.planId,
      duration_days: gc.durationDays,
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: "validate_failed", message: String(e?.message ?? e) });
  }
});

app.post("/gift-codes/redeem", requireDvAuth(), async (req, res) => {
  if (!ensureDbOr501(res)) return;
  try {
    const code = typeof req.body?.code === "string" ? req.body.code.trim().toUpperCase() : "";
    if (!code) return res.status(400).json({ ok: false, error: "missing_code" });

    const result = await redeemGiftCodePg(code, req.dvUser.canvaUserId);
    if (!result.ok) return res.json(result);

    return res.json({ ok: true, plan_id: result.planId });
  } catch (e) {
    res.status(500).json({ ok: false, error: "redeem_failed", message: String(e?.message ?? e) });
  }
});

// Sync and affirmation endpoints have been removed.
// User data is now backed up via encrypted Google Drive archives.
// Only auth, subscription, encryption key, and gift code endpoints remain.

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

