import { describe, expect, it } from 'vitest';
import { createApp } from '../../src/app.js';
import { createDatabase } from '../../src/db/client.js';
import { keys, projectId } from '../helpers/firebase-token.js';
import { createParseService } from '../../src/services/parse-service.js';
import { createPlanService } from '../../src/services/plan-service.js';
import type { LlmProvider } from '../../src/llm/provider.js';
import { testDatabaseUrl } from '../setup/database.js';

const { db } = createDatabase(testDatabaseUrl);
const provider: LlmProvider = {
  name: 'unused',
  model: 'claude-haiku-4-5',
  parse: () => Promise.reject(new Error('not used')),
};

function appWith(isReady: () => Promise<boolean>) {
  return createApp({
    auth: { keys, projectId },
    planService: createPlanService(db),
    parseService: createParseService({ provider, db }),
    isReady,
  });
}

describe('GET /ready', () => {
  it('is 200 when the database answers', async () => {
    const res = await appWith(() => Promise.resolve(true)).request('/ready');

    expect(res.status).toBe(200);
    await expect(res.json()).resolves.toEqual({ ready: true });
  });

  it('is 503 when it does not', async () => {
    const res = await appWith(() => Promise.resolve(false)).request('/ready');

    expect(res.status).toBe(503);
    await expect(res.json()).resolves.toEqual({ ready: false });
  });

  it('is 503, not 500, when the check itself throws', async () => {
    // A dependency being down is an expected state, not a bug in this service.
    const res = await appWith(() => Promise.reject(new Error('ECONNREFUSED'))).request('/ready');

    expect(res.status).toBe(503);
  });

  it('needs no token — the platform has none', async () => {
    const res = await appWith(() => Promise.resolve(true)).request('/ready');

    expect(res.status).not.toBe(401);
  });
});
