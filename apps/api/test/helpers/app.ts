import type { Database } from '../../src/db/client.js';
import { createApp } from '../../src/app.js';
import type { LlmProvider } from '../../src/llm/provider.js';
import { createParseService } from '../../src/services/parse-service.js';
import { createPlanService } from '../../src/services/plan-service.js';
import { keys, projectId } from './firebase-token.js';

/** Fails loudly rather than quietly returning nothing, for tests that never parse. */
const unusedProvider: LlmProvider = {
  name: 'unused',
  model: 'claude-haiku-4-5',
  parse: () => Promise.reject(new Error('this test should not have called the model')),
};

/**
 * Builds the app the way index.ts does, with the test key set and the test
 * database. Pass a provider when the test is about parsing.
 */
export function buildTestApp({
  db,
  provider = unusedProvider,
}: {
  db: Database['db'];
  provider?: LlmProvider;
}) {
  return createApp({
    auth: { keys, projectId },
    planService: createPlanService(db),
    parseService: createParseService({ provider, db }),
  });
}
