import { describe, expect, it } from 'vitest';
import { createApp } from '../../src/app.js';
import { keys, projectId, signToken } from '../helpers/firebase-token.js';

const app = createApp({ auth: { keys, projectId } });

describe('GET /me', () => {
  it('returns the caller identified by the token', async () => {
    const res = await app.request('/me', {
      headers: { Authorization: `Bearer ${await signToken({ subject: 'firebase-sub-xyz' })}` },
    });

    expect(res.status).toBe(200);
    await expect(res.json()).resolves.toEqual({ userId: 'firebase-sub-xyz' });
  });

  it('refuses a request without a token', async () => {
    const res = await app.request('/me');

    expect(res.status).toBe(401);
    await expect(res.json()).resolves.toEqual({
      error: { code: 'unauthorized', message: 'Unauthorized' },
    });
  });

  it('leaves /health public', async () => {
    expect((await app.request('/health')).status).toBe(200);
  });
});
