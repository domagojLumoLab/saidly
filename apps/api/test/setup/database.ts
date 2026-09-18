import { drizzle } from 'drizzle-orm/postgres-js';
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import postgres from 'postgres';
import { migrationsFolder } from '../../src/db/migrations-folder.js';

/**
 * Tests run against their own database so a test never touches development data.
 * Defaults to the Docker Postgres from docker-compose.yml, so `pnpm test` works
 * with no .env at all.
 */
export const testDatabaseUrl =
  process.env.TEST_DATABASE_URL ?? 'postgres://saidly:saidly@localhost:5432/saidly_test';

/**
 * `CREATE DATABASE` cannot run inside the database it creates — connect to the
 * maintenance database first. Keeps CI and a fresh laptop working without an
 * extra manual step.
 */
async function ensureDatabaseExists(url: string): Promise<void> {
  const parsed = new URL(url);
  const databaseName = parsed.pathname.slice(1);

  const maintenance = postgres(new URL('/postgres', parsed).toString(), { max: 1 });
  try {
    const rows = await maintenance`select 1 from pg_database where datname = ${databaseName}`;
    if (rows.length === 0) {
      await maintenance.unsafe(`create database "${databaseName}"`);
    }
  } finally {
    await maintenance.end();
  }
}

/** Vitest global setup: runs once before the whole suite. */
export async function setup(): Promise<void> {
  await ensureDatabaseExists(testDatabaseUrl);

  const client = postgres(testDatabaseUrl, { max: 1 });
  try {
    await migrate(drizzle(client), { migrationsFolder });
  } finally {
    await client.end();
  }
}
