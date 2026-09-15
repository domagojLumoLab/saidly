import { serve } from '@hono/node-server';
import { app } from './app.js';
import { loadConfig } from './lib/config.js';
import { logger } from './lib/logger.js';

const config = loadConfig();

serve({ fetch: app.fetch, port: config.PORT }, (info) => {
  logger.info({ port: info.port, env: config.NODE_ENV }, 'saidly api listening');
});
