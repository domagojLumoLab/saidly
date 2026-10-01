/**
 * Measures the parser against eval/cases.json: how often it gets the dates and
 * times right, what it costs, how long it takes.
 *
 *   pnpm eval
 *   pnpm eval --model claude-sonnet-5
 *
 * It lives inside apps/api rather than at the repository root because it runs
 * the API's own code and needs its dependencies; a file outside the package
 * cannot resolve them.
 *
 * Runs the real service against the test database under a fresh user id, so a
 * run neither pollutes development data nor eats into the daily cap.
 *
 * Titles are reported but never asserted. A title is cosmetic, the user
 * confirms it on screen, and demanding an exact string would measure the
 * model's phrasing rather than its understanding. Dates and instants are what
 * a notification fires on, so those are the pass condition.
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import Anthropic from '@anthropic-ai/sdk';
import { eq } from 'drizzle-orm';
import { createDatabase } from '../src/db/client.js';
import { aiCalls } from '../src/db/schema.js';
import { createAnthropicProvider } from '../src/llm/anthropic-provider.js';
import type { ParsedTask } from '../src/llm/parsed-plan.js';
import { createParseService } from '../src/services/parse-service.js';

type Expected = {
  date?: string;
  dateBetween?: [string, string];
  startsAt?: string | null;
  endsAt?: string | null;
  priority?: string;
};

type Case = {
  id: string;
  why: string;
  text: string;
  expect: Expected[];
  timeZone?: string;
};
type Suite = { now: string; timeZone: string; cases: Case[] };

const suite: Suite = JSON.parse(
  readFileSync(fileURLToPath(new URL('./cases.json', import.meta.url)), 'utf8'),
);

const model =
  process.argv[process.argv.indexOf('--model') + 1] !== undefined &&
  process.argv.includes('--model')
    ? process.argv[process.argv.indexOf('--model') + 1]!
    : 'claude-haiku-4-5';

const databaseUrl =
  process.env.TEST_DATABASE_URL ?? 'postgres://saidly:saidly@localhost:5432/saidly_test';

/** Returns the reasons a case failed; empty means it passed. */
function check(expected: Expected[], actual: ParsedTask[]): string[] {
  if (expected.length !== actual.length) {
    return [`expected ${expected.length} task(s), got ${actual.length}`];
  }

  const problems: string[] = [];

  expected.forEach((want, i) => {
    const got = actual[i]!;
    const say = (field: string, w: unknown, g: unknown) =>
      problems.push(`task ${i}: ${field} expected ${String(w)}, got ${String(g)}`);

    if (want.date !== undefined && got.date !== want.date) say('date', want.date, got.date);

    if (want.dateBetween && (got.date < want.dateBetween[0] || got.date > want.dateBetween[1])) {
      say('date', `between ${want.dateBetween.join(' and ')}`, got.date);
    }

    for (const field of ['startsAt', 'endsAt'] as const) {
      if (want[field] !== undefined && got[field] !== want[field]) {
        say(field, want[field], got[field]);
      }
    }

    if (want.priority !== undefined && got.priority !== want.priority) {
      say('priority', want.priority, got.priority);
    }
  });

  return problems;
}

const { db, client } = createDatabase(databaseUrl);
const userId = `eval-${Date.now()}`;
const service = createParseService({
  provider: createAnthropicProvider({
    client: new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY }),
    model,
  }),
  db,
});

console.log(`\n${model}  ·  ${suite.cases.length} cases  ·  now ${suite.now}\n`);

let passed = 0;
const latencies: number[] = [];

for (const testCase of suite.cases) {
  const startedAt = Date.now();
  let problems: string[];
  let titles = '';

  try {
    const tasks = await service.parse({
      userId,
      text: testCase.text,
      timeZone: testCase.timeZone ?? suite.timeZone,
      now: new Date(suite.now),
    });
    problems = check(testCase.expect, tasks);
    titles = tasks.map((task: ParsedTask) => task.title).join(' | ');
  } catch (error) {
    problems = [`threw: ${(error as Error).message}`];
  }

  const took = Date.now() - startedAt;
  latencies.push(took);
  if (problems.length === 0) passed += 1;

  console.log(
    `  ${problems.length === 0 ? '✓' : '✗'} ${testCase.id.padEnd(26)} ${String(took / 1000).padStart(5)}s  ${titles}`,
  );
  for (const problem of problems) console.log(`      ${problem}`);
  if (problems.length > 0) console.log(`      (${testCase.why})`);
}

const spent = await db.select().from(aiCalls).where(eq(aiCalls.userId, userId));
const cost = spent.reduce(
  (total: number, row: { costUsd: string }) => total + Number(row.costUsd),
  0,
);
const average = latencies.reduce((a, b) => a + b, 0) / latencies.length / 1000;

console.log(
  `\n  ${passed}/${suite.cases.length} (${Math.round((passed / suite.cases.length) * 100)}%)` +
    `   $${cost.toFixed(4)} over ${spent.length} call(s)   avg ${average.toFixed(1)}s\n`,
);

await client.end();
process.exit(passed === suite.cases.length ? 0 : 1);
