import { afterAll, describe, expect, it } from 'vitest';
import { createApp } from '../../src/app.js';
import { createDatabase } from '../../src/db/client.js';
import { createPlanService } from '../../src/services/plan-service.js';
import { version } from '../../src/lib/version.js';
import { keys, projectId } from '../helpers/firebase-token.js';
import { testDatabaseUrl } from '../setup/database.js';

const { db, client } = createDatabase(testDatabaseUrl);
const app = createApp({ auth: { keys, projectId }, planService: createPlanService(db) });

afterAll(async () => {
  await client.end();
});

describe('GET /health', () => {
  it('returns ok and the package version', async () => {
    const res = await app.request('/health');

    expect(res.status).toBe(200);
    await expect(res.json()).resolves.toEqual({ ok: true, version });
  });
});
