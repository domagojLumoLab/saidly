import { inArray } from 'drizzle-orm';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { createApp } from '../../src/app.js';
import { createDatabase } from '../../src/db/client.js';
import { plans } from '../../src/db/schema.js';
import { createPlanService } from '../../src/services/plan-service.js';
import { keys, projectId, signToken } from '../helpers/firebase-token.js';
import { testDatabaseUrl } from '../setup/database.js';

const { db, client } = createDatabase(testDatabaseUrl);
const app = createApp({ auth: { keys, projectId }, planService: createPlanService(db) });

const ana = 'sub-routes-ana';
const marko = 'sub-routes-marko';
const date = '2026-09-22';

const anaToken = await signToken({ subject: ana });
const markoToken = await signToken({ subject: marko });

const body = {
  date,
  timeZone: 'Europe/Zagreb',
  rawText: 'sutra ustati u 7, harmonika 19:00-20:30',
  tasks: [
    { title: 'Harmonika', startsAt: '2026-09-22T17:00:00Z', endsAt: '2026-09-22T18:30:00Z' },
    { title: 'Ustati', startsAt: '2026-09-22T05:00:00Z', priority: 'high' },
  ],
};

function post(token: string, payload: unknown = body) {
  return app.request('/plans', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
}

afterAll(async () => {
  await client.end();
});

beforeEach(async () => {
  await db.delete(plans).where(inArray(plans.userId, [ana, marko]));
});

describe('POST /plans', () => {
  it('stores the plan and returns it with task ids', async () => {
    const res = await post(anaToken);

    expect(res.status).toBe(201);
    const created = (await res.json()) as { id: string; tasks: { id: string; title: string }[] };
    expect(created.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(created.tasks.map((t) => t.title).sort()).toEqual(['Harmonika', 'Ustati']);
    expect(created.tasks.every((t) => t.id)).toBe(true);
  });

  it('ignores a userId in the body and trusts the token', async () => {
    const res = await post(anaToken, { ...body, userId: marko });

    expect(res.status).toBe(201);
    expect(
      await (
        await app.request(`/tasks?date=${date}`, {
          headers: { Authorization: `Bearer ${markoToken}` },
        })
      ).json(),
    ).toEqual({ tasks: [] });
  });

  it('refuses a request without a token', async () => {
    const res = await app.request('/plans', { method: 'POST', body: JSON.stringify(body) });

    expect(res.status).toBe(401);
  });

  it.each([
    ['no tasks', { ...body, tasks: [] }],
    ['a malformed date', { ...body, date: '22.09.2026.' }],
    ['an empty title', { ...body, tasks: [{ title: '' }] }],
    [
      'endsAt before startsAt',
      {
        ...body,
        tasks: [
          { title: 'Krivo', startsAt: '2026-09-22T18:00:00Z', endsAt: '2026-09-22T17:00:00Z' },
        ],
      },
    ],
  ])('refuses a body with %s', async (_label, payload) => {
    const res = await post(anaToken, payload);

    expect(res.status).toBe(400);
    expect((await res.json()) as { error: { code: string } }).toMatchObject({
      error: { code: 'invalid_request' },
    });
  });
});

describe('GET /tasks', () => {
  it('returns the day in order for the caller', async () => {
    await post(anaToken);

    const res = await app.request(`/tasks?date=${date}`, {
      headers: { Authorization: `Bearer ${anaToken}` },
    });

    expect(res.status).toBe(200);
    const { tasks } = (await res.json()) as { tasks: { title: string }[] };
    expect(tasks.map((t) => t.title)).toEqual(['Ustati', 'Harmonika']);
  });

  it("never returns another user's tasks", async () => {
    await post(anaToken);

    const res = await app.request(`/tasks?date=${date}`, {
      headers: { Authorization: `Bearer ${markoToken}` },
    });

    expect(await res.json()).toEqual({ tasks: [] });
  });

  it('refuses a missing or malformed date', async () => {
    const res = await app.request('/tasks', {
      headers: { Authorization: `Bearer ${anaToken}` },
    });

    expect(res.status).toBe(400);
  });
});
