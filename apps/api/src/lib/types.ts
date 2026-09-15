import type { RequestIdVariables } from 'hono/request-id';

/** Hono environment shared by the app, middleware and routes. */
export type AppEnv = {
  Variables: RequestIdVariables;
};
