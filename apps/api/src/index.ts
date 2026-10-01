import { serve } from '@hono/node-server';
import Anthropic from '@anthropic-ai/sdk';
import { createApp } from './app.js';
import { sql } from 'drizzle-orm';
import { createDatabase } from './db/client.js';
import { googleSecureTokenKeys } from './lib/auth.js';
import { createSentryReporter, noopErrorReporter } from './lib/error-reporter.js';
import { loadConfig } from './lib/config.js';
import { logger } from './lib/logger.js';
import { createAnthropicProvider } from './llm/anthropic-provider.js';
import { createParseService } from './services/parse-service.js';
import { createPlanService } from './services/plan-service.js';

const config = loadConfig();

// The composition root: the real database, the real keys and the real project
// id are wired together here, and nowhere else.
const { db, client } = createDatabase(config.DATABASE_URL);

// No DSN — development, tests, CI — means errors stay in the log.
const errorReporter = config.SENTRY_DSN
  ? createSentryReporter({ dsn: config.SENTRY_DSN, environment: config.NODE_ENV })
  : noopErrorReporter;

const app = createApp({
  auth: {
    keys: googleSecureTokenKeys(),
    projectId: config.FIREBASE_PROJECT_ID,
  },
  planService: createPlanService(db),
  parseService: createParseService({
    provider: createAnthropicProvider({
      client: new Anthropic({ apiKey: config.ANTHROPIC_API_KEY }),
      model: config.ANTHROPIC_MODEL,
    }),
    db,
  }),
  // The cheapest question that proves the database is reachable and answering.
  isReady: async () => {
    await db.execute(sql`select 1`);
    return true;
  },
  errorReporter,
});

const server = serve({ fetch: app.fetch, port: config.PORT }, (info) => {
  // Says out loud whether reporting is on: a mistyped SENTRY_DSN would
  // otherwise leave the app looking healthy while errors go nowhere.
  logger.info(
    {
      port: info.port,
      env: config.NODE_ENV,
      errorReporting: errorReporter === noopErrorReporter ? 'off' : 'sentry',
    },
    'saidly api listening',
  );
});

/**
 * Everything above this line only sees errors that happen inside a request —
 * `onError` is reached through the Hono stack. An error thrown from a timer, a
 * rejected promise nobody awaited, or anything during startup bypasses all of
 * it and kills the process silently.
 */
async function fatal(kind: string, error: unknown): Promise<never> {
  logger.fatal({ err: error }, kind);

  errorReporter.report(error, {
    requestId: 'process',
    method: kind,
    path: '-',
  });

  // Without this the report is still queued when the process ends.
  await errorReporter.flush();

  process.exit(1);
}

process.on('uncaughtException', (error) => void fatal('uncaughtException', error));
process.on('unhandledRejection', (reason) => void fatal('unhandledRejection', reason));

/**
 * Railway sends SIGTERM on every deploy. Stop taking new connections, let the
 * ones in flight finish, release the database, and send anything Sentry still
 * holds.
 */
async function shutdown(signal: string): Promise<void> {
  logger.info({ signal }, 'shutting down');

  server.close();
  await Promise.all([client.end(), errorReporter.flush()]);

  process.exit(0);
}

process.on('SIGTERM', () => void shutdown('SIGTERM'));
process.on('SIGINT', () => void shutdown('SIGINT'));
