import { migrate } from 'drizzle-orm/postgres-js/migrator';
import { loadConfig } from '../lib/config.js';
import { logger } from '../lib/logger.js';
import { createDatabase } from './client.js';
import { migrationsFolder } from './migrations-folder.js';

const config = loadConfig();
const { db, client } = createDatabase(config.DATABASE_URL);

await migrate(db, { migrationsFolder });
await client.end();

logger.info({ database: 'applied' }, 'migrations up to date');
