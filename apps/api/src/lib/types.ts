import type { RequestIdVariables } from 'hono/request-id';

/** Hono environment shared by the app, middleware and public routes. */
export type AppEnv = {
  Variables: RequestIdVariables;
};

/**
 * Environment for routes mounted behind `requireAuth`, which guarantees that
 * `userId` is set — hence `string` and not `string | undefined`.
 */
export type AuthedEnv = {
  Variables: RequestIdVariables & { userId: string };
};
