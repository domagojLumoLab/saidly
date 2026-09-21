import { describe, expect, it } from 'vitest';
import { createApp } from '../../src/app.js';
import { version } from '../../src/lib/version.js';
import { keys, projectId } from '../helpers/firebase-token.js';

const app = createApp({ auth: { keys, projectId } });

describe('GET /health', () => {
  it('returns ok and the package version', async () => {
    const res = await app.request('/health');

    expect(res.status).toBe(200);
    await expect(res.json()).resolves.toEqual({ ok: true, version });
  });
});
