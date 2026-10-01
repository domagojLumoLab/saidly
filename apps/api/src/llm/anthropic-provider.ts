import type Anthropic from '@anthropic-ai/sdk';
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod';
import { AppError } from '../lib/errors.js';
import { parsedPlanSchema } from './parsed-plan.js';
import type { LlmProvider, LlmResponse, ParseRequest } from './provider.js';

/**
 * A hard ceiling before validation sees anything: twenty tasks of JSON fit
 * comfortably, and the model cannot produce an answer that costs real money.
 */
const MAX_TOKENS = 1024;

function systemPrompt({ timeZone, localDate, weekday }: ParseRequest): string {
  return `You turn a few sentences about a day into a list of tasks. The user writes in their own language, usually Croatian.

Today is ${weekday} ${localDate} in the user's time zone, ${timeZone}. Resolve every relative expression — "sutra", "prekosutra", "u ponedjeljak", "za tjedan dana" — against that date.

Return every instant in UTC, converted from the user's local time. Use the offset that zone has on the task's own date, not today's — it changes with daylight saving.

In Croatian, "pola <n>" means thirty minutes BEFORE n o'clock, not after: "pola osam" is 07:30 and not 08:30, "pola devet" is 08:30 and not 09:30.

For each task:
- title: what to do, in the user's language, without the time in it. Start it with a capital letter even when the user did not.
- date: the calendar day the task belongs to, in the user's zone
- startsAt: when it begins, or null when the text gives no start
- endsAt: when it ends or is due, or null
- priority: high only when the text marks something as urgent or gives a hard deadline; otherwise normal. Use low only when the user plays something down.

A task with only a deadline ("prije podne", "do 15h") has endsAt and no startsAt. A task with no time at all ("kupiti kruh") has neither.

If the text contains no plan at all, return an empty list. Do not invent tasks.`;
}

export function createAnthropicProvider({
  client,
  model,
}: {
  client: Anthropic;
  model: string;
}): LlmProvider {
  return {
    name: 'anthropic',
    model,

    async parse(request: ParseRequest): Promise<LlmResponse> {
      const startedAt = performance.now();

      const content = request.correction
        ? `${request.text}\n\nYour previous answer was rejected: ${request.correction}. Answer again, correctly.`
        : request.text;

      let response;
      try {
        response = await client.messages.parse({
          model,
          max_tokens: MAX_TOKENS,
          system: systemPrompt(request),
          messages: [{ role: 'user', content }],
          output_config: { format: zodOutputFormat(parsedPlanSchema) },
        });
      } catch (cause) {
        // A failure to reach the model is not our bug and not the caller's:
        // the SDK has already retried what is worth retrying.
        throw new AppError('parser_unavailable', 'The parser is unavailable', 502, { cause });
      }

      return {
        // May be null when the model's answer did not fit the schema. The
        // service decides what to do about that; the provider only reports.
        output: response.parsed_output,
        usage: {
          tokensIn: response.usage.input_tokens,
          tokensOut: response.usage.output_tokens,
          latencyMs: Math.round(performance.now() - startedAt),
        },
      };
    },
  };
}
