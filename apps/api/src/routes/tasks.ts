import { Hono } from 'hono';
import { z } from 'zod';
import type { AuthedEnv } from '../lib/types.js';
import { validate } from '../lib/validate.js';
import type { PlanService } from '../services/plan-service.js';

const dayQuerySchema = z.object({ date: z.iso.date() });

export function createTaskRoutes(service: PlanService) {
  return new Hono<AuthedEnv>().get('/', validate('query', dayQuerySchema), async (c) => {
    const { date } = c.req.valid('query');

    return c.json({ tasks: await service.tasksForDay(c.get('userId'), date) });
  });
}
