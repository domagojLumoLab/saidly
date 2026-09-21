import { Hono } from 'hono';
import type { AuthedEnv } from '../lib/types.js';

/**
 * Echoes back who the caller is. Exists so the whole auth path can be checked
 * with curl, and so the mobile app has one endpoint to point at while wiring
 * sign-in — before any feature depends on it.
 */
export const meRoutes = new Hono<AuthedEnv>().get('/', (c) => c.json({ userId: c.get('userId') }));
