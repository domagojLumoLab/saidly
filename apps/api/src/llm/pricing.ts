/**
 * The only place model prices may live, per CLAUDE.md.
 *
 * Dollars per million tokens, checked 2026-09-25 against claude.com/pricing.
 * `docs/providers.md` shows what these work out to per thousand calls and how
 * the figures were derived.
 */
export type ModelPricing = {
  inputPerMTok: number;
  outputPerMTok: number;
};

export const pricing: Record<string, ModelPricing> = {
  'claude-haiku-4-5': { inputPerMTok: 1.0, outputPerMTok: 5.0 },
  'claude-sonnet-5': { inputPerMTok: 2.0, outputPerMTok: 10.0 },
};

const TOKENS_PER_MTOK = 1_000_000;

/** Matches the scale of ai_calls.cost_usd — numeric(12, 6). */
const DECIMALS = 6;

/**
 * Cost of one call, as a decimal string rather than a number: it is written
 * straight into a numeric column, and floats do not belong anywhere near money
 * that gets summed per user.
 *
 * An unknown model throws. Charging zero for it would be worse than failing —
 * every row written afterwards would understate the bill, and nothing would
 * say so.
 */
export function costUsd(model: string, tokensIn: number, tokensOut: number): string {
  const price = pricing[model];

  if (!price) {
    throw new Error(`No price for model "${model}" — add it to src/llm/pricing.ts`);
  }

  const total =
    (tokensIn * price.inputPerMTok) / TOKENS_PER_MTOK +
    (tokensOut * price.outputPerMTok) / TOKENS_PER_MTOK;

  return total.toFixed(DECIMALS);
}
