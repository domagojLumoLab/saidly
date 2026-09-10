# CLAUDE.md — working rules for Saidly

This file is read by Claude Code (and mirrored for other agents) whenever it works
in this repository. Keep it short, current and honest. When something here stops
being true, fix it in the same commit that changed the behaviour.

## What this project is

Saidly turns a few sentences about tomorrow ("wake at 7, call Marko before noon,
harmonica 19:00–20:30") into a structured plan with timed reminders. See README.md
for the product view and roadmap. Current milestone: **v0.1 — text input only**.

One developer, ~10 h/week, evenings. Prefer the boring, well-documented option.
Every feature must be finishable in a 2-hour session or split into pieces that are.

## Layout

```
apps/api      Hono + TypeScript (ESM) · Drizzle ORM · Postgres 16 · Vitest
apps/mobile   Flutter 3.x · Riverpod · Dio · firebase_auth · flutter_local_notifications
eval/         Parser test cases (JSON) and runner
docs/         Architecture, decisions (docs/decisions/NNN-title.md), provider notes
```

## Commands

```bash
# apps/api
pnpm dev            # start with tsx --watch on :3000
pnpm test           # Vitest against the Docker Postgres (TEST_DATABASE_URL)
pnpm lint           # eslint + prettier --check
pnpm typecheck      # tsc --noEmit
pnpm db:generate    # drizzle-kit generate (after editing src/db/schema.ts)
pnpm db:migrate     # apply migrations
pnpm eval           # run eval/ cases against configured providers

# apps/mobile
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs   # Riverpod/Freezed codegen
```

CI runs lint, typecheck and test on every PR; `main` deploys automatically. Never
push to `main` directly.

## Architecture rules (API)

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

## Architecture rules (mobile)

- Feature-first folders: `lib/features/<feature>/{data,domain,presentation}`.
- State: Riverpod only. No new state-management libraries.
- Networking: one Dio instance with an interceptor that attaches the Firebase
  ID token (`getIdToken()`) and force-refreshes it once on 401.
- Every screen handles loading, error (with retry) and empty states.
- Reminders are scheduled locally with `flutter_local_notifications`; the server
  never sends reminder pushes in v0.1.
- Strings are user-facing Croatian in v0.1; keep them in one place
  (`lib/l10n/`) so localisation later is mechanical.

## How to work here

1. Read the spec. Features arrive as a short spec in the issue or in
   `docs/specs/`. If there is no spec, ask for one or write a 5-line proposal
   before coding.
2. Tests first when the behaviour is clear: write the failing Vitest/Flutter test,
   show it, then implement.
3. Small diffs. One feature or fix per PR. If a change touches both `apps/api`
   and `apps/mobile`, land the API first with backward compatibility.
4. After changing code run the relevant `lint`, `typecheck`, `test` (or
   `flutter analyze`, `flutter test`) and report the result — do not claim green
   without running.
5. Explain trade-offs briefly in the PR description. Non-obvious decisions get a
   file in `docs/decisions/`.

## Do not

- Do not add dependencies without saying why in the PR; prefer the standard
  library and what is already installed.
- Do not commit secrets, `.env` files or API keys. `.env.example` documents the keys.
- Do not change the `ai_calls` schema or pricing without updating `pnpm eval`.
- Do not rewrite or reformat files you were not asked to touch.
- Do not introduce voice/audio features before v0.2 — text only in v0.1.
- Do not weaken auth, rate limiting or output validation to make a test pass.

## Conventions

- TypeScript: strict, ESM, named exports, `camelCase` for values,
  `PascalCase` for types, `kebab-case.ts` filenames.
- Dart: `flutter_lints` defaults, `snake_case.dart` filenames.
- Commits: Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`).
- Language: code, comments and docs in English; user-facing strings in Croatian
  (v0.1).
