import { describe, expect, it } from 'vitest';
import { costUsd, pricing } from '../../src/llm/pricing.js';

describe('costUsd', () => {
  it('prices one Haiku call', () => {
    // 400 in at $1/MTok = $0.0004, 150 out at $5/MTok = $0.00075
    expect(costUsd('claude-haiku-4-5', 400, 150)).toBe('0.001150');
  });

  it('reproduces the per-thousand figures from docs/providers.md', () => {
    // A thousand calls is 0.4M input and 0.15M output tokens.
    expect(costUsd('claude-haiku-4-5', 400_000, 150_000)).toBe('1.150000');
    expect(costUsd('claude-sonnet-5', 400_000, 150_000)).toBe('2.300000');
  });

  it('costs nothing when nothing was used', () => {
    expect(costUsd('claude-haiku-4-5', 0, 0)).toBe('0.000000');
  });

  it('refuses a model it has no price for', () => {
    // Silently charging zero would corrupt every ai_calls row written after a
    // model was added without its price.
    expect(() => costUsd('claude-something-new', 400, 150)).toThrow(/claude-something-new/);
  });

  it('keeps six decimals, because one call costs a fraction of a cent', () => {
    expect(costUsd('claude-haiku-4-5', 1, 1)).toBe('0.000006');
  });

  it('lists a price for every model the parser may use', () => {
    expect(Object.keys(pricing).sort()).toEqual(['claude-haiku-4-5', 'claude-sonnet-5']);
  });
});
