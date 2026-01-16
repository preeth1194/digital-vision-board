import fs from "node:fs/promises";
import path from "node:path";

import { getPool, hasDatabase } from "./db.js";

export async function ensureSchema() {
  if (!hasDatabase()) return;
  const pool = getPool();
  if (!pool) return;

  const sqlPath = path.resolve(process.cwd(), "sql", "001_init.sql");
  const sql = await fs.readFile(sqlPath, "utf-8");
  await pool.query(sql);
}

