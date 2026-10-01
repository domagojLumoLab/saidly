import { inArray } from 'drizzle-orm';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { createDatabase } from '../../src/db/client.js';
import { plans } from '../../src/db/schema.js';
import { createPlanService } from '../../src/services/plan-service.js';
import { testDatabaseUrl } from '../setup/database.js';

const { db, client } = createDatabase(testDatabaseUrl);
const service = createPlanService(db);

const ana = 'firebase-sub-ana';
const marko = 'firebase-sub-marko';
const date = '2026-09-22';

afterAll(async () => {
  await client.end();
});

// Only this file's users: other test files run in parallel against the same
// database.
beforeEach(async () => {
  await db.delete(plans).where(inArray(plans.userId, [ana, marko]));
});

function input(userId: string) {
  return {
    userId,
    date,
    timeZone: 'Europe/Zagreb',
    rawText: 'sutra ustati u 7, harmonika 19:00-20:30',
    tasks: [
      {
        title: 'Harmonika',
        startsAt: new Date('2026-09-22T17:00:00Z'),
        endsAt: new Date('2026-09-22T18:30:00Z'),
      },
      { title: 'Ustati', startsAt: new Date('2026-09-22T05:00:00Z'), priority: 'high' as const },
    ],
  };
}

describe('createPlan', () => {
  it('stores the plan and its tasks and returns them with ids', async () => {
    const created = await service.createPlan(input(ana));

    expect(created.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(created.rawText).toBe('sutra ustati u 7, harmonika 19:00-20:30');
    expect(created.tasks).toHaveLength(2);
    expect(created.tasks.every((t) => t.id && t.planId === created.id)).toBe(true);
  });

  it('writes nothing when one task is invalid', async () => {
    const broken = input(ana);
    broken.tasks[0]!.startsAt = new Date('not a date');

    await expect(service.createPlan(broken)).rejects.toThrow();
    expect(
      await db
        .select()
        .from(plans)
        .where(inArray(plans.userId, [ana])),
    ).toHaveLength(0);
  });
});

describe('markDone', () => {
  it('records when a task was finished', async () => {
    const created = await service.createPlan(input(ana));
    const task = created.tasks[0]!;

    const updated = await service.markDone(ana, task.id, true);

    expect(updated.doneAt).toBeInstanceOf(Date);
    expect(await service.tasksForDay(ana, date)).toContainEqual(
      expect.objectContaining({ id: task.id, doneAt: updated.doneAt }),
    );
  });

  it('can undo it', async () => {
    const created = await service.createPlan(input(ana));
    const task = created.tasks[0]!;
    await service.markDone(ana, task.id, true);

    expect((await service.markDone(ana, task.id, false)).doneAt).toBeNull();
  });

  it("refuses another user's task, and says nothing about whether it exists", async () => {
    const created = await service.createPlan(input(ana));

    await expect(service.markDone(marko, created.tasks[0]!.id, true)).rejects.toMatchObject({
      code: 'not_found',
      status: 404,
    });
  });

  it("refuses an id that is nobody's", async () => {
    await expect(
      service.markDone(ana, '00000000-0000-0000-0000-000000000000', true),
    ).rejects.toMatchObject({ code: 'not_found' });
  });
});

describe('tasksForDay', () => {
  it('returns the day in order, untimed tasks last', async () => {
    const plan = input(ana);
    await service.createPlan({ ...plan, tasks: [...plan.tasks, { title: 'Kupiti kruh' }] });

    const tasks = await service.tasksForDay(ana, date);

    expect(tasks.map((t) => t.title)).toEqual(['Ustati', 'Harmonika', 'Kupiti kruh']);
  });

  it('merges every plan submitted for that day', async () => {
    await service.createPlan(input(ana));
    await service.createPlan({
      ...input(ana),
      rawText: 'jos nazvati Marka',
      tasks: [{ title: 'Nazvati Marka' }],
    });

    expect(await service.tasksForDay(ana, date)).toHaveLength(3);
  });

  it("never returns another user's tasks", async () => {
    await service.createPlan(input(ana));

    expect(await service.tasksForDay(marko, date)).toEqual([]);
  });

  it('ignores other days', async () => {
    await service.createPlan(input(ana));

    expect(await service.tasksForDay(ana, '2026-09-23')).toEqual([]);
  });
});
