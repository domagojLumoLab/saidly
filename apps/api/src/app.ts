import { Hono } from 'hono';
import { requestId } from 'hono/request-id';
import { onError } from './lib/errors.js';
import { requestLogger } from './lib/request-logger.js';
import type { AppEnv } from './lib/types.js';
import { healthRoutes } from './routes/health.js';

/**
 * Builds the Hono app. Kept separate from the server entry point so tests can
 * drive it with `app.request()` without opening a port.
 */
export function createApp() {
  const app = new Hono<AppEnv>();

  app.use('*', requestId());
  app.use('*', requestLogger());

  app.route('/health', healthRoutes);

  app.onError(onError);

  return app;
}

export const app = createApp();
