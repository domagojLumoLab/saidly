import { and, asc, eq, getTableColumns, inArray, sql } from 'drizzle-orm';
import type { Database } from '../db/client.js';
import { NotFoundError } from '../lib/errors.js';
import type { Task } from '../db/schema.js';
import { plans, tasks } from '../db/schema.js';

export type NewTaskInput = {
  title: string;
  startsAt?: Date;
  endsAt?: Date;
  priority?: 'low' | 'normal' | 'high';
};

export type NewPlanInput = {
  /** Firebase `sub`, always taken from the verified token. */
  userId: string;
  /** Calendar day the plan is for, `YYYY-MM-DD`. */
  date: string;
  timeZone: string;
  rawText: string;
  tasks: NewTaskInput[];
};

export type PlanService = ReturnType<typeof createPlanService>;

/**
 * Timed tasks first in clock order, untimed ones after them in the order they
 * were entered. Drizzle has no helper for NULLS LAST, so this is raw SQL; in
 * Postgres an ascending sort would otherwise put NULLs at the end anyway, but
 * saying it out loud keeps the intent from depending on a default.
 */
const dayOrder = [sql`${tasks.startsAt} asc nulls last`, asc(tasks.createdAt)];

export function createPlanService(db: Database['db']) {
  return {
    /**
     * Writes the plan and its tasks in one transaction: a plan without its
     * tasks would be a lie, so either both land or neither does.
     */
    async createPlan(input: NewPlanInput) {
      return db.transaction(async (tx) => {
        const [plan] = await tx
          .insert(plans)
          .values({
            userId: input.userId,
            date: input.date,
            timeZone: input.timeZone,
            rawText: input.rawText,
          })
          .returning();

        // `.returning()` is typed as an array, so TypeScript cannot know it
        // holds exactly one row. Check it instead of asserting it away.
        if (!plan) throw new Error('inserting a plan returned no row');

        const stored = await tx
          .insert(tasks)
          .values(input.tasks.map((task) => ({ ...task, planId: plan.id })))
          .returning();

        return { ...plan, tasks: stored };
      });
    },

    /**
     * Marks a task finished, or unfinished again. `done_at` carries both facts:
     * whether, and when.
     *
     * Ownership is part of the same statement rather than a lookup before it —
     * a task is only reachable through a plan the caller owns. A task that
     * belongs to someone else is reported as missing, because confirming it
     * exists would already say too much.
     */
    async markDone(userId: string, taskId: string, done: boolean): Promise<Task> {
      const [updated] = await db
        .update(tasks)
        .set({ doneAt: done ? new Date() : null })
        .where(
          and(
            eq(tasks.id, taskId),
            inArray(
              tasks.planId,
              db.select({ id: plans.id }).from(plans).where(eq(plans.userId, userId)),
            ),
          ),
        )
        .returning();

      if (!updated) throw new NotFoundError('Task not found');

      return updated;
    },

    /**
     * Every task the user has for that day, from all plans submitted for it.
     * Timed tasks come first in clock order; untimed ones trail behind in the
     * order they were entered.
     */
    async tasksForDay(userId: string, date: string): Promise<Task[]> {
      return db
        .select(getTableColumns(tasks))
        .from(tasks)
        .innerJoin(plans, eq(tasks.planId, plans.id))
        .where(and(eq(plans.userId, userId), eq(plans.date, date)))
        .orderBy(...dayOrder);
    },
  };
}
