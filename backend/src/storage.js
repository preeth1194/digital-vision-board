import fs from "node:fs/promises";
import path from "node:path";

import { hasDatabase } from "./db.js";
import {
  deletePkceStatePg,
  findUserByDvTokenPg,
  getPkceStatePg,
  getUserRecordPg,
  putPkceStatePg,
  putUserRecordPg,
} from "./storage_pg.js";

const dataDir = path.resolve(process.cwd(), "data");
const tmpDir = path.resolve(process.cwd(), "tmp");

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
  } catch (e) {
    return fallback;
  }
}

function userFile(canvaUserId) {
  return path.join(dataDir, "users", `${canvaUserId}.json`);
}

function pkceFile() {
  return path.join(dataDir, "pkce_states.json");
}

export async function getPkceState(state) {
  if (hasDatabase()) return await getPkceStatePg(state);
  const all = await readJson(pkceFile(), {});
  return all[state] ?? null;
}

export async function putPkceState(state, record) {
  if (hasDatabase()) return await putPkceStatePg(state, record);
  const all = await readJson(pkceFile(), {});
  all[state] = record;
  await atomicWriteJson(pkceFile(), all);
}

export async function deletePkceState(state) {
  if (hasDatabase()) return await deletePkceStatePg(state);
  const all = await readJson(pkceFile(), {});
  delete all[state];
  await atomicWriteJson(pkceFile(), all);
}

export async function getUserRecord(canvaUserId) {
  if (hasDatabase()) return await getUserRecordPg(canvaUserId);
  return await readJson(userFile(canvaUserId), null);
}

export async function putUserRecord(canvaUserId, record) {
  if (hasDatabase()) return await putUserRecordPg(canvaUserId, record);
  await atomicWriteJson(userFile(canvaUserId), record);
}

export async function findUserByDvToken(dvToken) {
  if (hasDatabase()) return await findUserByDvTokenPg(dvToken);
  // Minimal implementation: scan user files (OK for dev; replace with DB later).
  // Keeps task-1 simple while unblocking the Canva panel + Flutter import work.
  const usersDir = path.join(dataDir, "users");
  await ensureDir(usersDir);
  const entries = await fs.readdir(usersDir);
  for (const name of entries) {
    if (!name.endsWith(".json")) continue;
    const rec = await readJson(path.join(usersDir, name), null);
    if (rec?.dvToken === dvToken) return rec;
  }
  return null;
}

