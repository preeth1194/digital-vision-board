import pg from "pg";

let pool = null;

export function hasDatabase() {
  return Boolean(process.env.DATABASE_URL);
}

export function getPool() {
  if (!process.env.DATABASE_URL) return null;
  if (pool) return pool;

  const { Pool } = pg;
  pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.PGSSL === "false" ? false : process.env.NODE_ENV === "production" ? { rejectUnauthorized: false } : false,
    max: Number(process.env.PG_POOL_MAX ?? 5),
  });

  return pool;
}

export async function withClient(fn) {
  const p = getPool();
  if (!p) throw new Error("DATABASE_URL not set");
  const client = await p.connect();
  try {
    return await fn(client);
  } finally {
    client.release();
  }
}

