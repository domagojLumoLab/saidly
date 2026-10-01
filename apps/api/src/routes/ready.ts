import { Hono } from 'hono';
import { logger } from '../lib/logger.js';
import type { AppEnv } from '../lib/types.js';

/**
 * Readiness, as opposed to liveness. `/health` says the process is up;
 * this says it can do its job — which for this service means the database
 * answers.
 *
 * The distinction is not academic: production ran for a week with a green
 * `/health` and no tables in the database, because `/health` never asked.
 */
export function createReadyRoutes(isReady: () => Promise<boolean>) {
  return new Hono<AppEnv>().get('/', async (c) => {
    let ready: boolean;

    try {
      ready = await isReady();
    } catch (err) {
      // A dependency being down is an expected state, not a bug here — so it
      // is a 503 and not the 500 the error handler would produce.
      logger.warn({ requestId: c.get('requestId'), err }, 'not ready');
      ready = false;
    }

    return ready ? c.json({ ready: true }) : c.json({ ready: false }, 503);
  });
}
