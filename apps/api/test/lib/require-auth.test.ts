import { Hono } from 'hono';
import { describe, expect, it } from 'vitest';
import { noopErrorReporter } from '../../src/lib/error-reporter.js';
import { onError } from '../../src/lib/errors.js';
import { requireAuth } from '../../src/lib/require-auth.js';
import type { AuthedEnv } from '../../src/lib/types.js';
import { keys, projectId, signToken } from '../helpers/firebase-token.js';

const validToken = await signToken();

/** A throwaway app: the middleware, one protected route, the real error handler. */
function makeApp() {
  const app = new Hono<AuthedEnv>();
  app.use('*', requireAuth({ keys, projectId }));
  app.get('/protected', (c) => c.json({ userId: c.get('userId') }));
  app.onError(onError(noopErrorReporter));
  return app;
}

describe('requireAuth', () => {
  it('puts the token subject on the context', async () => {
    const res = await makeApp().request('/protected', {
      headers: { Authorization: `Bearer ${validToken}` },
    });

    expect(res.status).toBe(200);
    await expect(res.json()).resolves.toEqual({ userId: 'firebase-sub-abc' });
  });

  it.each([
    ['no Authorization header', undefined],
    ['a header that is not a bearer token', 'Basic dXNlcjpwYXNz'],
    ['a bearer token that is not a JWT', 'Bearer not-a-jwt'],
    ['an empty bearer token', 'Bearer '],
  ])('answers 401 to %s', async (_label, authorization) => {
    const res = await makeApp().request('/protected', {
      headers: authorization ? { Authorization: authorization } : {},
    });

    expect(res.status).toBe(401);
    await expect(res.json()).resolves.toEqual({
      error: { code: 'unauthorized', message: 'Unauthorized' },
    });
  });

  it('never tells the caller why the token failed', async () => {
    const expired = await signToken({ expiresIn: '-1h' });

    const res = await makeApp().request('/protected', {
      headers: { Authorization: `Bearer ${expired}` },
    });

    expect(res.status).toBe(401);
    expect(await res.text()).not.toMatch(/exp|expired|signature|audience/i);
  });
});
