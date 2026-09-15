import type { MiddlewareHandler } from 'hono';
import { logger } from './logger.js';
import type { AppEnv } from './types.js';

/**
 * Logs one line per request with the request id, method, path, status and
 * duration. Bodies are never logged.
 */
export function requestLogger(): MiddlewareHandler<AppEnv> {
  return async (c, next) => {
    const startedAt = performance.now();

    await next();

    logger.info(
      {
        requestId: c.get('requestId'),
        method: c.req.method,
        path: c.req.path,
        status: c.res.status,
        durationMs: Math.round(performance.now() - startedAt),
      },
      'request',
    );
  };
}
