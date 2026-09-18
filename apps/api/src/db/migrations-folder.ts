import { fileURLToPath } from 'node:url';

/**
 * Absolute path to the generated SQL migrations, resolved from this file rather
 * than from the current working directory — the test runner and `pnpm db:migrate`
 * are not started from the same place.
 */
export const migrationsFolder = fileURLToPath(new URL('./migrations', import.meta.url));
