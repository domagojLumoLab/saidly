# CLAUDE.md — working rules for Saidly

This file is read by Claude Code (and mirrored for other agents) whenever it works
in this repository. Keep it short, current and honest. When something here stops
being true, fix it in the same commit that changed the behaviour.

Each app has its own `CLAUDE.md` with its commands and architecture rules.
Claude Code loads it automatically when it works inside that folder. This file
holds only what is shared.

## What this project is

Saidly turns a few sentences about tomorrow ("wake at 7, call Marko before noon,
harmonica 19:00–20:30") into a structured plan with timed reminders. See README.md
for the product view and roadmap. Current milestone: **v0.1 — text input only**.

One developer, ~10 h/week, evenings. Prefer the boring, well-documented option.
Every feature must be finishable in a 2-hour session or split into pieces that are.

The project also exists to build the developer's senior iOS skills. **In
`apps/ios` the developer writes the code himself** — see the rules there before
touching any Swift file.

## Layout

```
apps/api      Hono + TypeScript (ESM) · Drizzle ORM · Postgres 16 · Vitest  → apps/api/CLAUDE.md
apps/api/eval Parser cases (cases.json) and runner — inside the package because
              it runs the API's code and needs its dependencies
apps/ios      Swift 6 · SwiftUI · iOS 26+ · Swift Testing · FirebaseAuth      → apps/ios/CLAUDE.md
apps/flutter  Flutter 3.x · Riverpod 3 — PAUSED (docs/decisions/003)         → apps/flutter/CLAUDE.md
docs/         Architecture, decisions (docs/decisions/NNN-title.md), specs, provider notes
```

## CI and deployment

CI runs on every PR (`.github/workflows/ci.yml`), one job per package: lint,
typecheck, build and test for `apps/api`; format, analyze and test for
`apps/flutter`. The iOS job arrives with the Xcode project. `main` is protected
and a red check blocks the merge. Merging into `main` deploys the API to
Railway, which runs the migrations before traffic moves. Never push to `main`
directly.

## The contract between the apps and the API

These rules bind every client, so they live here and not in one app's file.

- Auth is Firebase Authentication. Clients send the Firebase ID token as
  `Authorization: Bearer <token>`; on a 401 they force-refresh the token once
  and retry once. The API verifies the token itself (see `apps/api/CLAUDE.md`).
  All clients are apps in the same Firebase project (`saidly-fa231`).
- Timestamps travel as ISO 8601 and are stored in UTC. Every request that
  depends on "today" carries the user's IANA time zone.
- Reminders are local notifications scheduled on the device; the server never
  sends reminder pushes in v0.1.
- A change that touches the API and a client lands in the API first, backward
  compatible, then in the client.

## How to work here

1. Read the spec. Features arrive as a short spec in the issue or in
   `docs/specs/`. If there is no spec, ask for one or write a 5-line proposal
   before coding.
2. Tests first when the behaviour is clear: write the failing test, show it,
   then implement.
3. Small diffs. One feature or fix per PR.
4. After changing code run that app's lint, typecheck/analyze and tests (see
   its `CLAUDE.md`) and report the result — do not claim green without running.
5. Explain trade-offs briefly in the PR description. Non-obvious decisions get a
   file in `docs/decisions/`.

## Do not

- Do not add dependencies without saying why in the PR; prefer the standard
  library and what is already installed.
- Do not commit secrets, `.env` files or API keys. `.env.example` documents the keys.
  One named exception: Firebase client configs are committed —
  `apps/flutter/lib/firebase_options.dart`,
  `apps/flutter/ios/Runner/GoogleService-Info.plist`,
  `apps/flutter/android/app/google-services.json` and
  `apps/ios/Saidly/GoogleService-Info.plist`. A Firebase client config is
  shipped inside every binary and authorises nothing on its own — see
  `docs/decisions/002`. The test: a value that reaches every user is public by
  construction; a value the server holds is not.
- Do not rewrite or reformat files you were not asked to touch.
- Do not introduce voice/audio features before v0.2 — text only in v0.1.
- Do not weaken auth, rate limiting or output validation to make a test pass.

## Conventions

- TypeScript: strict, ESM, named exports, `camelCase` for values,
  `PascalCase` for types, `kebab-case.ts` filenames.
- Swift: Swift API Design Guidelines, `swift format` defaults, one primary type
  per file named after it (`PlanViewModel.swift`).
- Dart: `flutter_lints` defaults, `snake_case.dart` filenames.
- Commits: Conventional Commits with the app as scope —
  `feat(api):`, `feat(ios):`, `fix(flutter):`, `docs:`, `ci:`, `chore:`.
- Language: code, comments and docs in English. User-facing strings in English
  first, Croatian alongside. The parser accepts both: `pnpm eval` covers English
  and Croatian cases, and the prompt says so.
- No AI attribution lines in commit messages or PR descriptions.
