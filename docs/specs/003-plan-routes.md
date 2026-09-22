# 003 — Writing and reading a day's plan

First route that reaches the database. Walks `routes/` → `services/` → `db/`
end to end, behind `requireAuth`.

## Endpoints

### `POST /plans` → 201

Creates a plan and its tasks in one transaction.

```json
{
  "date": "2026-09-22",
  "timeZone": "Europe/Zagreb",
  "rawText": "sutra ustati u 7, harmonika 19:00-20:30",
  "tasks": [
    { "title": "Ustati", "startsAt": "2026-09-22T05:00:00Z", "priority": "normal" },
    { "title": "Harmonika", "startsAt": "2026-09-22T17:00:00Z", "endsAt": "2026-09-22T18:30:00Z" }
  ]
}
```

Returns the stored plan with its tasks, ids included — the mobile app needs
them to schedule notifications and to mark a task done later.

### `GET /tasks?date=2026-09-22` → 200

Returns that day's tasks for the caller, ordered by `startsAt` with the untimed
ones last.

## Decisions

- **`POST /plans`, not `POST /tasks`.** The request creates a plan row and its
  task rows; naming it after the plan matches what is stored. Tasks are read
  through `GET /tasks` because that is what a screen asks for.
- **`userId` always comes from the verified token**, never from the body or the
  query. A body field named `userId` is ignored, not honoured.
- **One request, one transaction.** A plan without its tasks would be a lie, so
  either both land or neither does.
- **`rawText` is required even without a parser.** Until `/parse` exists the
  client sends the text the user typed alongside the tasks; the column stays
  honest from day one.
- **A service layer exists even though it is thin**, because the API rules in
  CLAUDE.md say routes never touch the database. `PlanService` owns the
  transaction; the route only validates and translates HTTP.
- **Several plans per day are allowed.** The schema has no unique constraint on
  `(user_id, date)` and adding one now would force a decision about what a
  second submission means — replace, merge, or refuse. `GET /tasks` therefore
  returns tasks from every plan for that day. Revisit when the confirmation
  screen exists.

## Validation

Body and query go through Zod with `@hono/zod-validator`, per CLAUDE.md. Rules
worth naming: `date` is `YYYY-MM-DD`, `timeZone` is a non-empty IANA string,
`tasks` has at least one entry, `title` is non-empty, `endsAt` may not precede
`startsAt`, `priority` is one of the enum values and defaults to `normal`.

A body that fails validation is `400 {"error":{"code":"invalid_request"}}`.

## Out of scope

`PATCH /tasks/:id` (marking done), deleting, editing a plan, `/parse`, the LLM,
pagination.

## Done when

Tests cover: a plan with two tasks round-trips through `POST` then `GET`; a
second user does not see it; an invalid body is refused; `GET` without a token
is 401; `endsAt` before `startsAt` is refused.
