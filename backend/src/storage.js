import fs from "node:fs/promises";
import path from "node:path";

import { hasDatabase } from "./db.js";
import {
  findUserByDvTokenPg,
  getUserRecordPg,
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

function userFile(userId) {
  return path.join(dataDir, "users", `${userId}.json`);
}

export async function getUserRecord(userId) {
  if (hasDatabase()) return await getUserRecordPg(userId);
  return await readJson(userFile(userId), null);
}

export async function putUserRecord(userId, record) {
  if (hasDatabase()) return await putUserRecordPg(userId, record);
  await atomicWriteJson(userFile(userId), record);
}

export async function findUserByDvToken(dvToken) {
  if (hasDatabase()) return await findUserByDvTokenPg(dvToken);
  // Dev-only fallback: scan user JSON files.
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
