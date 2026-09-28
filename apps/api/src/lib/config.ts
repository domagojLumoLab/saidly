import { z } from 'zod';

/**
 * Environment contract. Parsed once at startup; a missing or malformed variable
 * kills the process before the server binds a port.
 *
 * GEMINI_API_KEY stays optional until a Gemini provider exists.
 */
const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().max(65535).default(3000),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  DATABASE_URL: z.url(),
  FIREBASE_PROJECT_ID: z.string().min(1),
  // Optional on purpose: with no DSN the SDK is never initialised, so local
  // development, tests and CI report nothing.
  SENTRY_DSN: z.url().optional(),
  // Required since POST /parse: without it the server starts and every parse
  // fails, which is worse than not starting.
  ANTHROPIC_API_KEY: z.string().min(1),
  // Priced in src/llm/pricing.ts, which refuses a model it has no price for.
  ANTHROPIC_MODEL: z.enum(['claude-haiku-4-5', 'claude-sonnet-5']).default('claude-haiku-4-5'),
  GEMINI_API_KEY: z.string().min(1).optional(),
});

export type Config = z.infer<typeof envSchema>;

/**
 * `KEY=` in a .env file gives an empty string, not an absent variable, which
 * would defeat every `.default()` and `.optional()` below. Treat empty as unset.
 */
function withoutEmptyValues(env: NodeJS.ProcessEnv): Record<string, string> {
  return Object.fromEntries(
    Object.entries(env).filter((entry): entry is [string, string] => {
      const [, value] = entry;
      return value !== undefined && value !== '';
    }),
  );
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = envSchema.safeParse(withoutEmptyValues(env));

  if (!parsed.success) {
    const issues = parsed.error.issues
      .map((issue) => `  ${issue.path.join('.') || '(root)'}: ${issue.message}`)
      .join('\n');
    throw new Error(`Invalid environment:\n${issues}`);
  }

  return parsed.data;
}
