import { Hono } from 'hono';
import type { AppEnv } from '../lib/types.js';
import { version } from '../lib/version.js';

/** Liveness probe. Deliberately does not touch the database. */
export const healthRoutes = new Hono<AppEnv>().get('/', (c) => c.json({ ok: true, version }));
