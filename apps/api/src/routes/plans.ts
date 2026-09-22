import { Hono } from 'hono';
import { z } from 'zod';
import type { AuthedEnv } from '../lib/types.js';
import { validate } from '../lib/validate.js';
import type { NewTaskInput, PlanService } from '../services/plan-service.js';

const taskSchema = z
  .object({
    title: z.string().min(1),
    startsAt: z.iso.datetime().optional(),
    endsAt: z.iso.datetime().optional(),
    priority: z.enum(['low', 'normal', 'high']).optional(),
  })
  .refine(
    (task) => !task.startsAt || !task.endsAt || new Date(task.endsAt) >= new Date(task.startsAt),
    { message: 'endsAt is before startsAt' },
  );

const createPlanSchema = z.object({
  date: z.iso.date(),
  timeZone: z.string().min(1),
  rawText: z.string().min(1),
  tasks: z.array(taskSchema).min(1),
});

/**
 * Timestamps arrive as ISO strings and the service wants `Date`s. Optional
 * fields are spread in only when present: `exactOptionalPropertyTypes` draws a
 * line between "absent" and "explicitly undefined".
 */
function toTaskInput(task: z.infer<typeof taskSchema>): NewTaskInput {
  return {
    title: task.title,
    ...(task.startsAt ? { startsAt: new Date(task.startsAt) } : {}),
    ...(task.endsAt ? { endsAt: new Date(task.endsAt) } : {}),
    ...(task.priority ? { priority: task.priority } : {}),
  };
}

export function createPlanRoutes(service: PlanService) {
  return new Hono<AuthedEnv>().post('/', validate('json', createPlanSchema), async (c) => {
    const body = c.req.valid('json');

    const plan = await service.createPlan({
      // Never from the body: the token is the only source of identity.
      userId: c.get('userId'),
      date: body.date,
      timeZone: body.timeZone,
      rawText: body.rawText,
      tasks: body.tasks.map(toTaskInput),
    });

    return c.json(plan, 201);
  });
}
