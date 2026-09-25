# 004 — Error reporting

## Goal

Find out that production broke without having to go and look. Today an error is
a pino line in Railway's log viewer, which nobody reads at 2am.

## What gets reported

Only errors the code did **not** expect. A rejected token is a 401 and normal
operation; a malformed body is a 400 and normal operation. Reporting those would
bury the one thing worth waking up for.

| | Sentry | log |
|---|---|---|
| `AppError` (401, 400, 404) | no | `warn`, with `cause` |
| anything else | **yes** | `error`, with the stack |

That line is already drawn in `onError`, which splits on `err instanceof
AppError`; reporting hangs off the same branch.

## What travels with a report

- `requestId` as a tag, so an issue points at the log lines for that request
- `userId` as a tag when the route was authenticated — a Firebase `sub`, opaque
  and useful for "does this hit one user or all of them"
- method, path, status
- **not the request body.** CLAUDE.md forbids logging user text in production and
  Sentry is not an exception; `sendDefaultPii` stays off.

## Configuration

`SENTRY_DSN` is optional. Absent — local development, tests, CI — the SDK is
never initialised and nothing is sent. `environment` comes from `NODE_ENV` and
`release` from the package version, so an issue says which deploy produced it.

No tracing: `@sentry/node` can sample performance data, we do not want it and it
is the reason the package is as large as it is.

## Out of scope

Uptime checks, alerting rules, source map upload, tracing, the mobile side.

## Done when

A test proves an `AppError` is not reported and an unknown error is, `SENTRY_DSN`
is set on Railway, and a deliberate error in production shows up as an issue.
