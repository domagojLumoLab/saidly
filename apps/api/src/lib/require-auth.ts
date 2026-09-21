import type { MiddlewareHandler } from 'hono';
import type { AuthOptions } from './auth.js';
import { verifyIdToken } from './auth.js';
import { UnauthorizedError } from './errors.js';
import type { AuthedEnv } from './types.js';

const BEARER = 'Bearer ';

/**
 * Turns the bearer token into `userId` on the context, or refuses the request.
 *
 * Mount it on the routes that need a user — `/health` stays public. The reason
 * for a refusal goes into `cause` and therefore into the log, never into the
 * response.
 */
export function requireAuth(options: AuthOptions): MiddlewareHandler<AuthedEnv> {
  return async (c, next) => {
    const header = c.req.header('Authorization');

    if (!header?.startsWith(BEARER)) {
      const reason = header
        ? 'Authorization header is not a bearer token'
        : 'no Authorization header';
      throw new UnauthorizedError({ cause: new Error(reason) });
    }

    const token = header.slice(BEARER.length).trim();
    if (!token) {
      throw new UnauthorizedError({ cause: new Error('empty bearer token') });
    }

    c.set('userId', await verifyIdToken(token, options));

    await next();
  };
}
