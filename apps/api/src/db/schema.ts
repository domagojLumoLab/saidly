import { relations } from 'drizzle-orm';
import { date, index, pgEnum, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

/**
 * These values are a decision made in docs/specs/001-task-storage.md, not a
 * requirement from README: the same list must appear in the parser prompt and
 * in the Zod schema that validates the model's output.
 */
export const taskPriority = pgEnum('task_priority', ['low', 'normal', 'high']);

/**
 * One plan is one thing the user typed for one day. `raw_text` is kept so a bad
 * parse can be debugged against the exact input.
 */
export const plans = pgTable(
  'plans',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    // Firebase `sub`. No users table — see the spec.
    userId: text('user_id').notNull(),
    // The calendar day the plan is for, deliberately a date and not a timestamp:
    // a 23:30 task must not slide into the next day when converted to UTC.
    date: date('date').notNull(),
    rawText: text('raw_text').notNull(),
    // IANA zone the text was parsed in, e.g. Europe/Zagreb.
    timeZone: text('time_zone').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [index('plans_user_date_idx').on(table.userId, table.date)],
);

/**
 * A task belongs to a plan; the owner and the day come from there. Both instants
 * are nullable because the three shapes in the README example differ: "wake at 7"
 * has only a start, "call Marko before noon" only an end, "harmonica 19:00-20:30"
 * both.
 */
export const tasks = pgTable(
  'tasks',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    planId: uuid('plan_id')
      .notNull()
      .references(() => plans.id, { onDelete: 'cascade' }),
    title: text('title').notNull(),
    startsAt: timestamp('starts_at', { withTimezone: true }),
    endsAt: timestamp('ends_at', { withTimezone: true }),
    priority: taskPriority('priority').notNull().default('normal'),
    // Null means not done; a value answers both "is it done" and "when".
    doneAt: timestamp('done_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [index('tasks_plan_id_idx').on(table.planId)],
);

export const plansRelations = relations(plans, ({ many }) => ({
  tasks: many(tasks),
}));

export const tasksRelations = relations(tasks, ({ one }) => ({
  plan: one(plans, { fields: [tasks.planId], references: [plans.id] }),
}));

export type Plan = typeof plans.$inferSelect;
export type NewPlan = typeof plans.$inferInsert;
export type Task = typeof tasks.$inferSelect;
export type NewTask = typeof tasks.$inferInsert;
