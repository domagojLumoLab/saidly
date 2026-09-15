import { pino } from 'pino';

// `||` and not `??`: an empty NODE_ENV / LOG_LEVEL (from a `KEY=` line in .env)
// is a string, so `??` would keep the empty value and pino would reject it.
const nodeEnv = process.env.NODE_ENV || 'development';
const level = process.env.LOG_LEVEL || (nodeEnv === 'test' ? 'silent' : 'info');

/**
 * Process-wide pino logger. Pretty in development, JSON in production, silent
 * under Vitest. Never log request bodies containing user text in production.
 */
export const logger = pino({
  level,
  ...(nodeEnv === 'development'
    ? { transport: { target: 'pino-pretty', options: { translateTime: true } } }
    : {}),
});
