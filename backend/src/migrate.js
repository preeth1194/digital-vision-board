import fs from "node:fs/promises";
import path from "node:path";

import { getPool, hasDatabase } from "./db.js";

export async function ensureSchema() {
  if (!hasDatabase()) return;
  const pool = getPool();
  if (!pool) return;

  const sqlDir = path.resolve(process.cwd(), "sql");
  const entries = await fs.readdir(sqlDir);
  const sqlFiles = entries
    .filter((n) => /^\d+_.+\.sql$/i.test(n))
    .sort((a, b) => a.localeCompare(b, "en", { numeric: true }));

  for (const file of sqlFiles) {
    const sqlPath = path.join(sqlDir, file);
    const sql = await fs.readFile(sqlPath, "utf-8");
    await pool.query(sql);
  }
}

