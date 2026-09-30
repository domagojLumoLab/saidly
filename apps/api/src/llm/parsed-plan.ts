import { z } from 'zod';

/**
 * What the model must return. Sent to the API as the response format, so the
 * shape is enforced server-side — and checked again here, because the server
 * guarantees shape and not meaning.
 *
 * The priority values are the ones in the database enum. All three lists — this
 * schema, the prompt, and src/db/schema.ts — have to agree.
 */
export const parsedTaskSchema = z
  .object({
    title: z.string().min(1).max(200),
    /** The calendar day the task belongs to, in the user's zone. */
    date: z.iso.date(),
    startsAt: z.iso.datetime().nullable(),
    endsAt: z.iso.datetime().nullable(),
    priority: z.enum(['low', 'normal', 'high']),
  })
  .refine((task) => !task.startsAt || !task.endsAt || task.endsAt >= task.startsAt, {
    message: 'endsAt is before startsAt',
  });

export const parsedPlanSchema = z.object({
  // Empty is a valid answer: "bok" contains no plan. Spec 005 returns 200 with
  // an empty list rather than an error.
  tasks: z.array(parsedTaskSchema).max(20),
});

export type ParsedTask = z.infer<typeof parsedTaskSchema>;
export type ParsedPlan = z.infer<typeof parsedPlanSchema>;
