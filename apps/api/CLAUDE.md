# apps/api — working rules for the Saidly API

Read together with the root `CLAUDE.md` (product, workflow, conventions).

## Commands

```bash
pnpm dev            # start with tsx --watch on :3000
pnpm build          # tsc -> dist/, plus the .sql migrations
pnpm start          # run the build: node dist/index.js
pnpm test           # Vitest against the Docker Postgres (TEST_DATABASE_URL)
pnpm lint           # eslint + prettier --check
pnpm typecheck      # tsc --noEmit
pnpm db:generate    # drizzle-kit generate (after editing src/db/schema.ts)
pnpm db:migrate     # apply migrations
pnpm eval           # accuracy, cost and latency over eval/cases.json
pnpm eval --model claude-sonnet-5   # same cases, another model
```

## Architecture rules

- Layers: `routes/` (HTTP only) → `services/` (business logic) → `db/` (Drizzle).
  Routes never touch the database directly. Services never import Hono types.
- Validate every request body and query with Zod via `@hono/zod-validator`.
  Validate every LLM output with Zod too — the model is untrusted input.
- Auth: verify the Firebase ID token with `jose` against Google's JWKS
  (`https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com`).
  Check `exp`, `aud` (= FIREBASE_PROJECT_ID) and `iss`
  (= `https://securetoken.google.com/<FIREBASE_PROJECT_ID>`); `sub` is the userId.
  No Firebase Admin SDK on the API. Do not implement our own auth.
- All LLM access goes through `src/llm/` behind the `LlmProvider` interface.
  Every call writes a row to `ai_calls` (provider, model, tokens in/out, cost,
  latency, user_id). Prices live in `src/llm/pricing.ts` only.
- Errors: throw typed `AppError`s in services; one error handler maps them to HTTP.
  Log with pino, always include the request id. Never log request bodies that
  contain user text in production.
- Timestamps are stored in UTC; the user's IANA time zone travels with the request
  and is passed to the parser prompt together with the current local date and
  weekday.
- Migrations are generated, reviewed and committed. Never edit an applied migration.

## Do not

- Do not change the `ai_calls` schema or pricing without updating `pnpm eval`.
