import fs from "node:fs/promises";
import path from "node:path";

import { hasDatabase } from "./db.js";
import {
  getWizardDefaultsPg,
  getWizardRecommendationsPg,
  putWizardDefaultsPg,
  upsertWizardRecommendationsPg,
} from "./wizard_storage_pg.js";

const dataDir = path.resolve(process.cwd(), "data");
const tmpDir = path.resolve(process.cwd(), "tmp");

function defaultsFile() {
  return path.join(dataDir, "wizard_defaults.json");
}

function recommendationsFile() {
  return path.join(dataDir, "wizard_recommendations_v2.json");
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

export async function getWizardDefaults() {
  if (hasDatabase()) return await getWizardDefaultsPg();
  const v = await readJson(defaultsFile(), null);
  if (!v) return null;
  return {
    defaults: v.defaults ?? v,
    updatedAt: v.updatedAt ?? null,
  };
}

export async function putWizardDefaults({ defaults }) {
  if (hasDatabase()) return await putWizardDefaultsPg({ defaults });
  const payload = {
    defaults: defaults ?? {},
    updatedAt: new Date().toISOString(),
  };
  await atomicWriteJson(defaultsFile(), payload);
}

export async function getWizardRecommendations({ coreValueId, categoryKey, genderKey }) {
  if (hasDatabase()) return await getWizardRecommendationsPg({ coreValueId, categoryKey, genderKey });
  const all = await readJson(recommendationsFile(), {});
  const gk = String(genderKey ?? "").trim() || "unisex";
  const k = `${coreValueId}::${categoryKey}::${gk}`;
  return all[k] ?? null;
}

export async function upsertWizardRecommendations({
  coreValueId,
  categoryKey,
  genderKey,
  categoryLabel,
  recommendations,
  source,
  createdBy,
}) {
  if (hasDatabase()) {
    return await upsertWizardRecommendationsPg({
      coreValueId,
      categoryKey,
      genderKey,
      categoryLabel,
      recommendations,
      source,
      createdBy,
    });
  }
  const all = await readJson(recommendationsFile(), {});
  const gk = String(genderKey ?? "").trim() || "unisex";
  const k = `${coreValueId}::${categoryKey}::${gk}`;
  all[k] = {
    coreValueId,
    categoryKey,
    genderKey: gk,
    categoryLabel,
    recommendations: recommendations ?? {},
    source: source ?? null,
    createdBy: createdBy ?? null,
    updatedAt: new Date().toISOString(),
  };
  await atomicWriteJson(recommendationsFile(), all);
}

