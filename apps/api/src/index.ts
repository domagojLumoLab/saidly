import { serve } from '@hono/node-server';
import { createApp } from './app.js';
import { googleSecureTokenKeys } from './lib/auth.js';
import { loadConfig } from './lib/config.js';
import { logger } from './lib/logger.js';

const config = loadConfig();

// The composition root: real keys and the real project id are wired in here,
// and nowhere else.
const app = createApp({
  auth: {
    keys: googleSecureTokenKeys(),
    projectId: config.FIREBASE_PROJECT_ID,
  },
});

serve({ fetch: app.fetch, port: config.PORT }, (info) => {
  logger.info({ port: info.port, env: config.NODE_ENV }, 'saidly api listening');
});
