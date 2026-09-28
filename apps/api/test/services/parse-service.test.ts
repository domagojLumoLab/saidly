import { eq } from 'drizzle-orm';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { createDatabase } from '../../src/db/client.js';
import { aiCalls } from '../../src/db/schema.js';
import { AppError } from '../../src/lib/errors.js';
import type { LlmProvider, ParseRequest } from '../../src/llm/provider.js';
import { createParseService } from '../../src/services/parse-service.js';
import { testDatabaseUrl } from '../setup/database.js';

const { db, client } = createDatabase(testDatabaseUrl);
const ana = 'sub-parse-ana';

/** Hands back queued answers and records what it was asked. */
function fakeProvider(outputs: unknown[]): LlmProvider & { seen: ParseRequest[] } {
  const seen: ParseRequest[] = [];
  return {
    name: 'fake',
    model: 'claude-haiku-4-5',
    seen,
    async parse(request) {
      seen.push(request);
      return {
        output: outputs.shift(),
        usage: { tokensIn: 400, tokensOut: 150, latencyMs: 12 },
      };
    },
  };
}

const goodPlan = {
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

/** 22:30 UTC on the 28th is already the 29th in Zagreb. */
const lateEvening = new Date('2026-09-28T22:30:00Z');

function parse(provider: LlmProvider, text = 'sutra ustati u 7') {
  return createParseService({ provider, db }).parse({
    userId: ana,
    text,
    timeZone: 'Europe/Zagreb',
    now: lateEvening,
  });
}

afterAll(async () => {
  await client.end();
});

beforeEach(async () => {
  await db.delete(aiCalls).where(eq(aiCalls.userId, ana));
});

describe('parse', () => {
  it('returns the tasks the model found', async () => {
    await expect(parse(fakeProvider([goodPlan]))).resolves.toEqual(goodPlan.tasks);
  });

  it('accepts finding nothing at all', async () => {
    await expect(parse(fakeProvider([{ tasks: [] }]))).resolves.toEqual([]);
  });

  it("tells the model which day it is in the user's zone", async () => {
    const provider = fakeProvider([goodPlan]);
    await parse(provider);

    // 22:30 UTC is 00:30 on the 29th in Zagreb — the date the user means.
    expect(provider.seen[0]).toMatchObject({
      localDate: '2026-09-29',
      weekday: 'Tuesday',
      timeZone: 'Europe/Zagreb',
      text: 'sutra ustati u 7',
    });
  });

  it('records the call with its cost', async () => {
    await parse(fakeProvider([goodPlan]));

    const [row] = await db.select().from(aiCalls).where(eq(aiCalls.userId, ana));
    expect(row).toMatchObject({
      provider: 'fake',
      model: 'claude-haiku-4-5',
      tokensIn: 400,
      tokensOut: 150,
      latencyMs: 12,
      costUsd: '0.001150',
    });
  });

  it('retries once when the model answers badly, and says what was wrong', async () => {
    const provider = fakeProvider([{ tasks: [{ title: '' }] }, goodPlan]);

    await expect(parse(provider)).resolves.toEqual(goodPlan.tasks);
    expect(provider.seen).toHaveLength(2);
    expect(provider.seen[0]?.correction).toBeUndefined();
    expect(provider.seen[1]?.correction).toBeTruthy();
  });

  it('charges for the retry too', async () => {
    await parse(fakeProvider([{ nonsense: true }, goodPlan]));

    expect(await db.select().from(aiCalls).where(eq(aiCalls.userId, ana))).toHaveLength(2);
  });

  it('gives up after the second bad answer', async () => {
    const provider = fakeProvider([{ nonsense: true }, { alsoNonsense: true }]);

    await expect(parse(provider)).rejects.toMatchObject({ code: 'parser_failed', status: 502 });
    await expect(parse(fakeProvider([goodPlan]))).resolves.toBeDefined();
    expect(provider.seen).toHaveLength(2);
  });

  it('refuses a task whose end precedes its start', async () => {
    const backwards = {
      tasks: [
        {
          title: 'Krivo',
          date: '2026-09-29',
          startsAt: '2026-09-29T18:00:00Z',
          endsAt: '2026-09-29T17:00:00Z',
          priority: 'normal',
        },
      ],
    };

    await expect(parse(fakeProvider([backwards, backwards]))).rejects.toBeInstanceOf(AppError);
  });
});
