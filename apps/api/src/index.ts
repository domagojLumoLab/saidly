import { serve } from '@hono/node-server';
import { createApp } from './app.js';
import { createDatabase } from './db/client.js';
import { googleSecureTokenKeys } from './lib/auth.js';
import { createSentryReporter, noopErrorReporter } from './lib/error-reporter.js';
import { loadConfig } from './lib/config.js';
import { logger } from './lib/logger.js';
import { createPlanService } from './services/plan-service.js';

const config = loadConfig();

// The composition root: the real database, the real keys and the real project
// id are wired together here, and nowhere else.
const { db } = createDatabase(config.DATABASE_URL);

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
  errorReporter,
});

serve({ fetch: app.fetch, port: config.PORT }, (info) => {
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
