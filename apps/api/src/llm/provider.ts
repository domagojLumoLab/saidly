import type { ParsedPlan } from './parsed-plan.js';

export type ParseRequest = {
  /** What the user typed. */
  text: string;
  /** IANA zone, e.g. Europe/Zagreb. */
  timeZone: string;
  /** Today in that zone — without it "sutra" has no referent. */
  localDate: string;
  /** Its weekday, for expressions like "u ponedjeljak". */
  weekday: string;
  /** Set on a retry: what was wrong with the previous answer. */
  correction?: string;
};

export type LlmUsage = {
  tokensIn: number;
  tokensOut: number;
  latencyMs: number;
};

export type LlmResponse = {
  /**
   * Unvalidated. The provider does not check it — validation and the decision
   * to retry belong to the service, so every provider behaves the same when a
   * model answers badly.
   */
  output: unknown;
  usage: LlmUsage;
};

/**
 * All model access goes through this, per CLAUDE.md. A provider makes one call
 * and reports what it cost; it does not retry, validate, or write to the
 * database.
 */
export type LlmProvider = {
  readonly name: string;
  readonly model: string;
  parse(request: ParseRequest): Promise<LlmResponse>;
};

export type { ParsedPlan };
