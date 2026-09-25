import type { Context, Env } from 'hono';
import type { RequestIdVariables } from 'hono/request-id';
import type { ContentfulStatusCode } from 'hono/utils/http-status';
import type { ErrorReporter } from './error-reporter.js';
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

/** A request body or query that Zod refused. */
export class InvalidRequestError extends AppError {
  constructor(message = 'Invalid request', options?: ErrorOptions) {
    super('invalid_request', message, 400, options);
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
 * code; anything else is logged in full, reported, and answered with an opaque
 * 500 so stack traces and driver messages never reach a client.
 *
 * Takes the reporter as an argument rather than importing one, so tests can see
 * what would be reported and nothing is sent from a test run.
 */
export function onError(reporter: ErrorReporter) {
  return <E extends { Variables: RequestIdVariables } & Env>(
    err: Error,
    c: Context<E>,
  ): Response => {
    const requestId = c.get('requestId');

    if (err instanceof AppError) {
      // Expected: a rejected token or a malformed body is normal operation.
      // Reporting these would bury the errors worth waking up for.
      logger.warn(
        {
          requestId,
          code: err.code,
          status: err.status,
          err: err.message,
          // pino only serialises an Error under the `err` key; anywhere else it
          // JSON.stringifies it, and an Error's message and stack are not
          // enumerable, so the reason came out as `{}` — the one thing this
          // field exists to carry.
          cause: err.cause instanceof Error ? err.cause.message : err.cause,
        },
        'app error',
      );
      return c.json({ error: { code: err.code, message: err.message } }, err.status);
    }

    logger.error({ requestId, err }, 'unhandled error');

    // `userId` exists only on authenticated routes, so it is read from the
    // untyped bag rather than through the typed `c.get`.
    const userId = (c.var as Record<string, unknown>)['userId'];

    reporter.report(err, {
      requestId,
      method: c.req.method,
      path: c.req.path,
      ...(typeof userId === 'string' ? { userId } : {}),
    });

    return c.json({ error: { code: 'internal_error', message: 'Internal server error' } }, 500);
  };
}
