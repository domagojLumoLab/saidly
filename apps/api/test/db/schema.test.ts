import { eq } from 'drizzle-orm';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { createDatabase } from '../../src/db/client.js';
import { plans, tasks } from '../../src/db/schema.js';
import { testDatabaseUrl } from '../setup/database.js';

const { db, client } = createDatabase(testDatabaseUrl);

afterAll(async () => {
  await client.end();
});

beforeEach(async () => {
  // Tasks go with the plan: the FK cascades.
  await db.delete(plans);
});

describe('plans and tasks', () => {
  it('stores a plan with two tasks and reads them back', async () => {
    const [plan] = await db
      .insert(plans)
      .values({
        userId: 'firebase-sub-abc',
        date: '2026-09-19',
        rawText: 'sutra ustati u 7, harmonika 19:00-20:30',
        timeZone: 'Europe/Zagreb',
      })
      .returning();

    expect(plan).toBeDefined();

    await db.insert(tasks).values([
      {
        planId: plan!.id,
        title: 'Ustati',
        startsAt: new Date('2026-09-19T05:00:00Z'),
        priority: 'high',
      },
      {
        planId: plan!.id,
        title: 'Harmonika',
        startsAt: new Date('2026-09-19T17:00:00Z'),
        endsAt: new Date('2026-09-19T18:30:00Z'),
      },
    ]);

    const stored = await db.query.plans.findFirst({
      where: eq(plans.id, plan!.id),
      with: { tasks: { orderBy: tasks.title } },
    });

    expect(stored?.rawText).toBe('sutra ustati u 7, harmonika 19:00-20:30');
    expect(stored?.date).toBe('2026-09-19');
    expect(stored?.tasks).toHaveLength(2);

    const [harmonika, ustati] = stored!.tasks;
    expect(harmonika?.title).toBe('Harmonika');
    expect(harmonika?.endsAt).toEqual(new Date('2026-09-19T18:30:00Z'));
    expect(harmonika?.priority).toBe('normal'); // column default
    expect(harmonika?.doneAt).toBeNull();

    expect(ustati?.priority).toBe('high');
    expect(ustati?.endsAt).toBeNull(); // "wake at 7" has no end
  });

  it('deletes tasks when their plan is deleted', async () => {
    const [plan] = await db
      .insert(plans)
      .values({ userId: 'u1', date: '2026-09-19', rawText: 'x', timeZone: 'Europe/Zagreb' })
      .returning();

    await db.insert(tasks).values({ planId: plan!.id, title: 'Only task' });

    await db.delete(plans).where(eq(plans.id, plan!.id));

    expect(await db.select().from(tasks)).toHaveLength(0);
  });
});
