import type { ZodType } from 'zod';
import { zValidator } from '@hono/zod-validator';
import { InvalidRequestError } from './errors.js';

/**
 * `zValidator`, but a failure becomes our own `AppError` so every rejected
 * request leaves through the one error handler and gets the same shape.
 *
 * Zod's own message lists which fields are wrong; it travels in `cause` to the
 * log. The client is told only that the request was invalid, because the
 * schema is ours and describing it back is of no use to a caller.
 */
export function validate<T extends ZodType>(target: 'json' | 'query', schema: T) {
  return zValidator(target, schema, (result) => {
    if (!result.success) {
      throw new InvalidRequestError(undefined, { cause: result.error });
    }
  });
}
