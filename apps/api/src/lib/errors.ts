import type { Context } from 'hono';
import type { ContentfulStatusCode } from 'hono/utils/http-status';
import { logger } from './logger.js';
import type { AppEnv } from './types.js';

/**
 * Errors thrown by services. `code` is a stable machine-readable string the
 * mobile app can switch on; `message` is safe to show to a client.
 */
export class AppError extends Error {
  readonly code: string;
  readonly status: ContentfulStatusCode;

  constructor(code: string, message: string, status: ContentfulStatusCode = 400) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.status = status;
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Resource not found') {
    super('not_found', message, 404);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized') {
    super('unauthorized', message, 401);
  }
}

/**
 * The single error handler. Known `AppError`s are mapped to their status and
 * code; anything else is logged in full and reported as an opaque 500 so
 * stack traces and driver messages never reach a client.
 */
export function onError(err: Error, c: Context<AppEnv>): Response {
  const requestId = c.get('requestId');

  if (err instanceof AppError) {
    logger.warn({ requestId, code: err.code, status: err.status, err: err.message }, 'app error');
    return c.json({ error: { code: err.code, message: err.message } }, err.status);
  }

  logger.error({ requestId, err }, 'unhandled error');
  return c.json({ error: { code: 'internal_error', message: 'Internal server error' } }, 500);
}
