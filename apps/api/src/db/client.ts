import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema.js';

export type Database = ReturnType<typeof createDatabase>;

/**
 * Builds a Drizzle client over a postgres-js connection pool. The caller owns
 * the pool and must close it (`client.end()`), which is why it is returned too.
 */
export function createDatabase(connectionString: string) {
  const client = postgres(connectionString);
  return { db: drizzle(client, { schema }), client };
}
