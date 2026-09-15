import { pino } from 'pino';

const nodeEnv = process.env.NODE_ENV ?? 'development';

/**
 * Process-wide pino logger. Pretty in development, JSON in production, silent
 * under Vitest. Never log request bodies containing user text in production.
 */
export const logger = pino({
  level: process.env.LOG_LEVEL ?? (nodeEnv === 'test' ? 'silent' : 'info'),
  ...(nodeEnv === 'development'
    ? { transport: { target: 'pino-pretty', options: { translateTime: true } } }
    : {}),
});
