import type { Context, Env } from 'hono';
import type { RequestIdVariables } from 'hono/request-id';
import type { ContentfulStatusCode } from 'hono/utils/http-status';
import { logger } from './logger.js';

/**
 * Errors thrown by services. `code` is a stable machine-readable string the
 * mobile app can switch on; `message` is safe to show to a client.
 */
export class AppError extends Error {
  readonly code: string;
  readonly status: ContentfulStatusCode;

  constructor(
    code: string,
    message: string,
    status: ContentfulStatusCode = 400,
    options?: ErrorOptions,
  ) {
    super(message, options);
    this.name = 'AppError';
    this.code = code;
    this.status = status;
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Resource not found', options?: ErrorOptions) {
    super('not_found', message, 404, options);
  }
}

/**
 * Takes no message on purpose: every rejected request gets the same words, so a
 * caller cannot tell an expired token from a forged one. Pass the real reason as
 * `cause` — the error handler logs it, the client never sees it.
 */
export class UnauthorizedError extends AppError {
  constructor(options?: ErrorOptions) {
    super('unauthorized', 'Unauthorized', 401, options);
  }
}

/**
 * The single error handler. Known `AppError`s are mapped to their status and
 * code; anything else is logged in full and reported as an opaque 500 so
 * stack traces and driver messages never reach a client.
 */
export function onError<E extends { Variables: RequestIdVariables } & Env>(
  err: Error,
  c: Context<E>,
): Response {
  const requestId = c.get('requestId');

  if (err instanceof AppError) {
    logger.warn(
      { requestId, code: err.code, status: err.status, err: err.message, cause: err.cause },
      'app error',
    );
    return c.json({ error: { code: err.code, message: err.message } }, err.status);
  }

  logger.error({ requestId, err }, 'unhandled error');
  return c.json({ error: { code: 'internal_error', message: 'Internal server error' } }, 500);
}
