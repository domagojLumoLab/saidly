import { inArray } from 'drizzle-orm';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { createApp } from '../../src/app.js';
import { createDatabase } from '../../src/db/client.js';
import { aiCalls } from '../../src/db/schema.js';
import type { LlmProvider } from '../../src/llm/provider.js';
import { createParseService } from '../../src/services/parse-service.js';
import { createPlanService } from '../../src/services/plan-service.js';
import { keys, projectId, signToken } from '../helpers/firebase-token.js';
import { testDatabaseUrl } from '../setup/database.js';

const { db, client } = createDatabase(testDatabaseUrl);
const ana = 'sub-parse-route-ana';
const token = await signToken({ subject: ana });

const plan = {
  tasks: [
    {
      title: 'Ustati',
      date: '2026-09-29',
      startsAt: '2026-09-29T05:00:00Z',
      endsAt: null,
      priority: 'high',
    },
  ],
};

function appWith(output: unknown): ReturnType<typeof createApp> {
  const provider: LlmProvider = {
    name: 'fake',
    model: 'claude-haiku-4-5',
    parse: () =>
      Promise.resolve({ output, usage: { tokensIn: 400, tokensOut: 150, latencyMs: 9 } }),
  };

  return createApp({
    auth: { keys, projectId },
    planService: createPlanService(db),
    parseService: createParseService({ provider, db }),
  });
}

function post(body: unknown, app = appWith(plan)) {
  return app.request('/parse', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

const good = { text: 'sutra ustati u 7', timeZone: 'Europe/Zagreb' };

afterAll(async () => {
  await client.end();
});

beforeEach(async () => {
  await db.delete(aiCalls).where(inArray(aiCalls.userId, [ana]));
});

describe('POST /parse', () => {
  it('returns the tasks the model found', async () => {
    const res = await post(good);

    expect(res.status).toBe(200);
    await expect(res.json()).resolves.toEqual({ tasks: plan.tasks });
  });

  it('records the call against the caller from the token', async () => {
    await post(good);

    const rows = await db
      .select()
      .from(aiCalls)
      .where(inArray(aiCalls.userId, [ana]));
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ provider: 'fake', costUsd: '0.001150' });
  });

  it('refuses a request without a token', async () => {
    const res = await appWith(plan).request('/parse', {
      method: 'POST',
      body: JSON.stringify(good),
    });

    expect(res.status).toBe(401);
  });

  it.each([
    ['no text', { timeZone: 'Europe/Zagreb' }],
    ['empty text', { ...good, text: '' }],
    ['more than 1000 characters', { ...good, text: 'a'.repeat(1001) }],
    ['no time zone', { text: 'sutra ustati u 7' }],
  ])('refuses a body with %s', async (_label, body) => {
    const res = await post(body);

    expect(res.status).toBe(400);
    await expect(res.json()).resolves.toMatchObject({ error: { code: 'invalid_request' } });
  });

  it('answers 200 with nothing when the text holds no plan', async () => {
    const res = await post({ ...good, text: 'bok' }, appWith({ tasks: [] }));

    expect(res.status).toBe(200);
    await expect(res.json()).resolves.toEqual({ tasks: [] });
  });

  it('answers 502 when the model will not produce a usable plan', async () => {
    const res = await post(good, appWith({ nonsense: true }));

    expect(res.status).toBe(502);
    await expect(res.json()).resolves.toMatchObject({ error: { code: 'parser_failed' } });
  });
});
