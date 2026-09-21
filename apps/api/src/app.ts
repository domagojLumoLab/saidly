import { Hono } from 'hono';
import { requestId } from 'hono/request-id';
import type { AuthOptions } from './lib/auth.js';
import { onError } from './lib/errors.js';
import { requestLogger } from './lib/request-logger.js';
import { requireAuth } from './lib/require-auth.js';
import type { AppEnv } from './lib/types.js';
import { healthRoutes } from './routes/health.js';
import { meRoutes } from './routes/me.js';

export type AppOptions = {
  /** Where token verification gets its keys, and which project to accept. */
  auth: AuthOptions;
};

/**
 * Builds the Hono app. Dependencies arrive as arguments so tests can pass their
 * own: importing this module must not reach the network or a database.
 */
export function createApp({ auth }: AppOptions) {
  const app = new Hono<AppEnv>();

  app.use('*', requestId());
  app.use('*', requestLogger());

  // Public.
  app.route('/health', healthRoutes);

  // Behind a valid Firebase ID token.
  app.use('/me', requireAuth(auth));
  app.route('/me', meRoutes);

  app.onError(onError);

  return app;
}
