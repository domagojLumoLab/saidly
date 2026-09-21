import { z } from 'zod';

/**
 * Environment contract. Parsed once at startup; a missing or malformed variable
 * kills the process before the server binds a port.
 *
 * ANTHROPIC_API_KEY / GEMINI_API_KEY are optional while there is no LLM code
 * (v0.1 skeleton). Make them required in the same commit that adds `src/llm/`.
 */
const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().max(65535).default(3000),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  DATABASE_URL: z.string().url(),
  // Only used by the test suite; the server never needs it.
  TEST_DATABASE_URL: z.string().url().optional(),
  FIREBASE_PROJECT_ID: z.string().min(1),
  ANTHROPIC_API_KEY: z.string().min(1).optional(),
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
