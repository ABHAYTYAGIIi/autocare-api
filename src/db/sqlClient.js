import pg from "pg";
import { getSqlConnectionConfiguration } from "./database.js";

let pool;
pg.types.setTypeParser(1700, (value) => Number.parseFloat(value));

export async function getSqlPool() {
  if (!pool) {
    const configuration = getSqlConnectionConfiguration();
    if (!configuration) throw new Error("PostgreSQL was requested without a SQL connection configuration.");
    pool = new pg.Pool(configuration);
  }
  return pool;
}

export async function initializeDatabase() {
  if (getSqlConnectionConfiguration()) {
    const client = await getSqlPool();
    await client.query("SELECT 1");
  }
}

export async function closeSqlPool() {
  if (pool) await pool.end();
  pool = undefined;
}
