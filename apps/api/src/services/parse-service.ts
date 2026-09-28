import type { Database } from '../db/client.js';
import { aiCalls } from '../db/schema.js';
import { AppError } from '../lib/errors.js';
import type { ParsedTask } from '../llm/parsed-plan.js';
import { parsedPlanSchema } from '../llm/parsed-plan.js';
import { costUsd } from '../llm/pricing.js';
import type { LlmProvider, ParseRequest } from '../llm/provider.js';

export type ParseInput = {
  /** Firebase `sub`, from the verified token. */
  userId: string;
  text: string;
  timeZone: string;
  /** Injected so tests do not depend on the wall clock. */
  now?: Date;
};

/** The model gets one correction and no more; a third call is rarely the one that works. */
const MAX_ATTEMPTS = 2;

/**
 * "Sutra" needs a today to be relative to, and that today belongs to the
 * user's zone rather than the server's. `en-CA` because it formats as
 * YYYY-MM-DD.
 */
function localDay(now: Date, timeZone: string): { localDate: string; weekday: string } {
  return {
    localDate: new Intl.DateTimeFormat('en-CA', { timeZone }).format(now),
    weekday: new Intl.DateTimeFormat('en-US', { timeZone, weekday: 'long' }).format(now),
  };
}

export type ParseService = ReturnType<typeof createParseService>;

export function createParseService({
  provider,
  db,
}: {
  provider: LlmProvider;
  db: Database['db'];
}) {
  return {
    /**
     * Asks the model, validates what comes back, and retries once with the
     * validation error as a correction. Every call is recorded in `ai_calls`,
     * including a retry — a retry is paid for.
     */
    async parse({ userId, text, timeZone, now = new Date() }: ParseInput): Promise<ParsedTask[]> {
      const { localDate, weekday } = localDay(now, timeZone);
      let correction: string | undefined;

      for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
        const request: ParseRequest = {
          text,
          timeZone,
          localDate,
          weekday,
          ...(correction ? { correction } : {}),
        };

        const { output, usage } = await provider.parse(request);

        await db.insert(aiCalls).values({
          userId,
          provider: provider.name,
          model: provider.model,
          tokensIn: usage.tokensIn,
          tokensOut: usage.tokensOut,
          costUsd: costUsd(provider.model, usage.tokensIn, usage.tokensOut),
          latencyMs: usage.latencyMs,
        });

        const parsed = parsedPlanSchema.safeParse(output);
        if (parsed.success) {
          return parsed.data.tasks;
        }

        correction = parsed.error.issues
          .map((issue) => `${issue.path.join('.') || '(root)'}: ${issue.message}`)
          .join('; ');
      }

      // The model is a dependency, and a dependency that will not answer
      // usefully is a bad gateway rather than our bug. The reason is logged
      // through `cause`, never returned.
      throw new AppError('parser_failed', 'Could not parse the plan', 502, {
        cause: new Error(correction),
      });
    },
  };
}
