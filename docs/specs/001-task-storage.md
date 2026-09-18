# 001 — Plan and task storage

## Goal

Persist a parsed plan and its tasks in Postgres. Schema and migrations only —
no routes, no services, no LLM, no auth.

## Schema

- **`plans`** — `id`, `user_id` (Firebase `sub`, plain text), `date` (the day the
  plan is for), `raw_text` (what the user typed), `time_zone` (IANA zone the text
  was parsed in), `created_at`. Indexed on `(user_id, date)`.
- **`tasks`** — `id`, `plan_id` (FK → `plans`, cascade delete), `title`,
  `starts_at`, `ends_at`, `priority`, `done_at`, `created_at`. Indexed on
  `plan_id`.

All instants are `timestamptz` (UTC); `plans.date` is a calendar day and
deliberately not a timestamp, so a 23:30 task does not slide into the next day.

## Decisions

- **`plans` holds the raw text.** This settles the conflict between README step 2
  ("`/parse` stores it") and CLAUDE.md's `PlanService` ("save confirmed plan"):
  `/parse` writes the plan, confirmation writes the tasks. It also keeps the
  original input for debugging a bad parse.
- **Tasks carry no `user_id` or `date`.** Both live on the plan; a task's owner is
  reached by joining. Avoids two copies of the same fact.
- **`done_at` instead of a `done` boolean.** "Is it done" is `done_at is not null`,
  and we get "when" for free.
- **`priority` is a Postgres enum** with `low | normal | high`. These values are not
  specified anywhere in README or CLAUDE.md — they are chosen here, and the same
  list must appear in the parser prompt and its Zod schema.
- **No `ai_calls` table yet.** CLAUDE.md requires it for every LLM call, but there
  is no LLM code; it lands with the parser. Migrations are additive, so adding it
  later costs nothing.

## Out of scope

Repositories, services, HTTP routes, seed data, `ai_calls`.

## Done when

`docker compose up -d` and `pnpm db:migrate` create both tables, the generated
migration is committed and reviewed, and a Vitest test applies the migration to
`TEST_DATABASE_URL` and inserts a plan with two tasks.
