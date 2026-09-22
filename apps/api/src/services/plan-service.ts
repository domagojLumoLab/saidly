import { and, asc, eq, getTableColumns, sql } from 'drizzle-orm';
import type { Database } from '../db/client.js';
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
