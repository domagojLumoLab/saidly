import { Hono } from 'hono';
import { z } from 'zod';
import type { AuthedEnv } from '../lib/types.js';
import { validate } from '../lib/validate.js';
import type { ParseService } from '../services/parse-service.js';

const parseRequestSchema = z.object({
  // A thousand characters is a generous day: the example in README is 66. It
  // also bounds what one call can cost.
  text: z.string().min(1).max(1000),
  // IANA zone. Without it "sutra" cannot be resolved, so it is required rather
  // than defaulted — a wrong guess would silently produce the wrong day.
  timeZone: z.string().min(1),
});

export function createParseRoutes(service: ParseService) {
  return new Hono<AuthedEnv>().post('/', validate('json', parseRequestSchema), async (c) => {
    const { text, timeZone } = c.req.valid('json');

    const tasks = await service.parse({
      // From the token, never the body: the caller does not get to say who
      // they are or whose quota to spend.
      userId: c.get('userId'),
      text,
      timeZone,
    });

    return c.json({ tasks });
  });
}
