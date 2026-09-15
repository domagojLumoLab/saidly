import { describe, expect, it } from 'vitest';
import { app } from '../../src/app.js';
import { version } from '../../src/lib/version.js';

describe('GET /health', () => {
  it('returns ok and the package version', async () => {
    const res = await app.request('/health');

    expect(res.status).toBe(200);
    await expect(res.json()).resolves.toEqual({ ok: true, version });
  });
});
