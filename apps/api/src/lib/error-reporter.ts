import * as Sentry from '@sentry/node';
import { version } from './version.js';

/** What travels with a report. Deliberately no request body — see spec 004. */
export type ErrorContext = {
  requestId: string;
  method: string;
  path: string;
  userId?: string;
};

/**
 * Reporting is an interface, not a direct Sentry call, so tests can assert what
 * would be reported without a network and without a DSN.
 */
export type ErrorReporter = {
  report(error: unknown, context: ErrorContext): void;
};

/** Used whenever SENTRY_DSN is absent: development, tests, CI. */
export const noopErrorReporter: ErrorReporter = {
  report() {},
};

export type SentryOptions = {
  dsn: string;
  environment: string;
};

export function createSentryReporter({ dsn, environment }: SentryOptions): ErrorReporter {
  Sentry.init({
    dsn,
    environment,
    // Tells an issue which deploy produced it.
    release: version,
    // No performance tracing: we want to know what broke, not how long it took,
    // and sampled traces are the reason this package is as big as it is.
    tracesSampleRate: 0,
    // Strip anything the SDK may have picked up about the request itself:
    // headers, cookies, query string, body. CLAUDE.md forbids logging user
    // text in production and Sentry is not an exception. Removing the field
    // beats trusting a flag, and survives an SDK that changes its defaults.
    beforeSend(event) {
      delete event.request;
      return event;
    },
  });

  return {
    report(error, { requestId, method, path, userId }) {
      Sentry.withScope((scope) => {
        scope.setTag('requestId', requestId);
        scope.setTag('method', method);
        scope.setTag('path', path);
        if (userId) scope.setTag('userId', userId);
        Sentry.captureException(error);
      });
    },
  };
}
