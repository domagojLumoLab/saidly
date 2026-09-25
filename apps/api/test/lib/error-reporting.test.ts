import { Hono } from 'hono';
import { requestId } from 'hono/request-id';
import { beforeEach, describe, expect, it } from 'vitest';
import type { ErrorContext, ErrorReporter } from '../../src/lib/error-reporter.js';
import { NotFoundError, UnauthorizedError, onError } from '../../src/lib/errors.js';
import type { AppEnv } from '../../src/lib/types.js';

const reported: { error: unknown; context: ErrorContext }[] = [];

/** Stands in for Sentry: records what would have been sent. */
const recordingReporter: ErrorReporter = {
  report(error, context) {
    reported.push({ error, context });
  },
};

function appThrowing(error: Error) {
  return new Hono<AppEnv>()
    .use('*', requestId())
    .get('/boom', () => {
      throw error;
    })
    .onError(onError(recordingReporter));
}

beforeEach(() => {
  reported.length = 0;
});

describe('error reporting', () => {
  it.each([
    ['an unauthorized request', new UnauthorizedError()],
    ['a missing resource', new NotFoundError()],
  ])('does not report %s', async (_label, error) => {
    await appThrowing(error).request('/boom');

    expect(reported).toEqual([]);
  });

  it('reports an error nobody expected', async () => {
    const bug = new Error('undefined is not a function');

    const res = await appThrowing(bug).request('/boom');

    expect(res.status).toBe(500);
    expect(reported).toHaveLength(1);
    expect(reported[0]?.error).toBe(bug);
  });

  it('sends the request id, method and path, and nothing about the body', async () => {
    await appThrowing(new Error('boom')).request('/boom');

    const context = reported[0]?.context;
    expect(context?.method).toBe('GET');
    expect(context?.path).toBe('/boom');
    expect(context?.requestId).toMatch(/^[0-9a-f-]{36}$/);
    expect(Object.keys(context ?? {}).sort()).toEqual(['method', 'path', 'requestId']);
  });
});
