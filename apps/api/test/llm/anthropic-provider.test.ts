import type Anthropic from '@anthropic-ai/sdk';
import { describe, expect, it } from 'vitest';
import { createAnthropicProvider } from '../../src/llm/anthropic-provider.js';
import type { ParseRequest } from '../../src/llm/provider.js';

type ParseParams = Parameters<Anthropic['messages']['parse']>[0];

/**
 * Stands in for the SDK client. Cast rather than implemented: the provider
 * touches one method, and mirroring the whole client would be a second, worse
 * copy of the SDK's types.
 */
function stubClient(reply: unknown | (() => never)) {
  const calls: ParseParams[] = [];
  const client = {
    messages: {
      parse(params: ParseParams) {
        calls.push(params);
        if (typeof reply === 'function') (reply as () => never)();
        return Promise.resolve({
          parsed_output: reply,
          usage: { input_tokens: 412, output_tokens: 96 },
        });
      },
    },
  } as unknown as Anthropic;

  return { client, calls };
}

const request: ParseRequest = {
  text: 'sutra ustati u 7',
  timeZone: 'Europe/Zagreb',
  localDate: '2026-09-29',
  weekday: 'Tuesday',
};

const plan = { tasks: [] };

describe('anthropic provider', () => {
  it('tells the model which day it is and in which zone', async () => {
    const { client, calls } = stubClient(plan);

    await createAnthropicProvider({ client, model: 'claude-haiku-4-5' }).parse(request);

    const system = String(calls[0]?.system);
    expect(system).toContain('Tuesday 2026-09-29');
    expect(system).toContain('Europe/Zagreb');
  });

  // The prompt used to assert a UTC offset computed for today, which was wrong
  // for any task past a daylight saving change — eval/cases.json caught it on
  // the first run. The zone name alone is now passed and the conversion is the
  // model's, so the check for it lives in the eval rather than here.

  it('sends the text alone on the first attempt', async () => {
    const { client, calls } = stubClient(plan);

    await createAnthropicProvider({ client, model: 'claude-haiku-4-5' }).parse(request);

    expect(calls[0]?.messages[0]?.content).toBe('sutra ustati u 7');
  });

  it('appends the correction on a retry', async () => {
    const { client, calls } = stubClient(plan);

    await createAnthropicProvider({ client, model: 'claude-haiku-4-5' }).parse({
      ...request,
      correction: 'tasks.0.title: too short',
    });

    expect(String(calls[0]?.messages[0]?.content)).toContain('tasks.0.title: too short');
  });

  it('reports what the call used', async () => {
    const { client } = stubClient(plan);

    const { output, usage } = await createAnthropicProvider({
      client,
      model: 'claude-haiku-4-5',
    }).parse(request);

    expect(output).toEqual(plan);
    expect(usage).toMatchObject({ tokensIn: 412, tokensOut: 96 });
    expect(usage.latencyMs).toBeGreaterThanOrEqual(0);
  });

  it('turns a failure to reach the model into a 502', async () => {
    const { client } = stubClient(() => {
      throw new Error('socket hang up');
    });

    await expect(
      createAnthropicProvider({ client, model: 'claude-haiku-4-5' }).parse(request),
    ).rejects.toMatchObject({ code: 'parser_unavailable', status: 502 });
  });

  it('passes a null answer through for the service to judge', async () => {
    const { client } = stubClient(null);

    const { output } = await createAnthropicProvider({
      client,
      model: 'claude-haiku-4-5',
    }).parse(request);

    expect(output).toBeNull();
  });
});
