import { Hono } from 'hono';
import { z } from 'zod';
import type { AuthedEnv } from '../lib/types.js';
import { validate } from '../lib/validate.js';
import type { PlanService } from '../services/plan-service.js';

const dayQuerySchema = z.object({ date: z.iso.date() });

/**
 * Checked here rather than left to Postgres: an id that is not a uuid fails the
 * cast deep in the driver and surfaces as a 500, when it is plainly a bad
 * request.
 */
const taskIdSchema = z.object({ id: z.uuid() });

const markDoneSchema = z.object({ done: z.boolean() });

export function createTaskRoutes(service: PlanService) {
  return new Hono<AuthedEnv>()
    .get('/', validate('query', dayQuerySchema), async (c) => {
      const { date } = c.req.valid('query');

      return c.json({ tasks: await service.tasksForDay(c.get('userId'), date) });
    })
    .patch('/:id', validate('param', taskIdSchema), validate('json', markDoneSchema), async (c) => {
      const { id } = c.req.valid('param');
      const { done } = c.req.valid('json');

      return c.json(await service.markDone(c.get('userId'), id, done));
    });
}
