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
apps/mobile   Flutter 3.x · Riverpod 3 (codegen) · go_router · Dio · firebase_auth · flutter_local_notifications
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
dart run custom_lint                                        # riverpod_lint rules
flutter test
dart run build_runner build --delete-conflicting-outputs   # @riverpod codegen
flutter gen-l10n                                            # regenerate strings from .arb
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

We follow the Riverpod app architecture from Code with Andrea
(codewithandrea.com/articles/flutter-app-architecture-riverpod-introduction/),
feature-first. Reference implementation: the `ecommerce_app` from the Flutter
Foundations course. Differences from that course are listed at the end.

### Folder structure

```
lib/
├── main.dart                      # bootstrap only: ProviderScope, error handlers, runApp
└── src/
    ├── app.dart                   # MaterialApp.router wired to goRouterProvider
    ├── common_widgets/            # truly shared widgets (AsyncValueWidget, PrimaryButton, alert dialogs…)
    ├── constants/                 # app_sizes.dart, breakpoints, api constants
    ├── exceptions/                # AppException sealed class + error_logger
    ├── features/
    │   ├── authentication/        # sign in / sign out / current user
    │   ├── plan/                  # enter text → parsed plan → confirm  (the core feature)
    │   ├── tasks/                 # today's tasks, mark done
    │   └── reminders/             # scheduling local notifications from tasks
    ├── localization/              # app_hr.arb (+ app_en.arb later), string_hardcoded.dart
    ├── routing/                   # app_router.dart, go_router_refresh_stream.dart, not_found_screen.dart
    └── utils/                     # async_value_ui.dart, date formatters, in_memory_store.dart
```

Each feature has up to four layers; create a folder only when it has content:

```
features/<feature>/
├── presentation/   widgets + controllers (screen_controller.dart next to screen.dart)
├── application/    services — ONLY when logic spans several repositories or is shared
├── domain/         immutable models: fromJson/toJson, ==, hashCode, copyWith
└── data/           repositories, data sources, DTOs
```

A feature is a functional requirement ("plan tomorrow", "get reminded"), not a
screen. Do not create `features/home_screen/`.

### Layer rules

- Dependencies point one way: presentation → application → domain ← data.
  Data never imports presentation; domain imports nothing but other domain models.
- **Domain**: plain immutable Dart classes (`Task`, `Plan`, `AppUser`). Freezed is
  allowed but not required; hand-written `copyWith`/`==` is fine for small models.
- **Data**: one repository per data source. `PlanRepository` (Dio → Saidly API),
  `AuthRepository` (wraps `firebase_auth`), `LocalNotificationsRepository`
  (wraps `flutter_local_notifications`). Repositories are concrete classes exposed
  as `Provider`s (`planRepositoryProvider`). They map DTOs/JSON into domain models
  and translate low-level errors into `AppException` subclasses. Nothing outside
  `data/` imports Dio, Firebase or notification packages.
- **Application**: a `XyzService` only when a controller would otherwise call two
  repositories (e.g. `PlanService`: save confirmed plan via API, then schedule
  reminders locally). If a service only forwards calls, delete it.
- **Presentation**: widgets are `ConsumerWidget`/`ConsumerStatefulWidget` and stay
  dumb — they `ref.watch` state, call controller methods, and show errors.
  Controllers are `AsyncNotifier` subclasses generated with `@riverpod`; they
  expose `AsyncValue<T>` and mutate with
  `state = const AsyncLoading(); state = await AsyncValue.guard(() => ...)`.
  Widgets react to errors with
  `ref.listen(controllerProvider, (_, s) => s.showAlertDialogOnError(context))`.
  Read-only async data is rendered with `AsyncValueWidget<T>`; every list has an
  empty state.
- Errors are `AppException(code, message)` subclasses in `src/exceptions/`; user
  messages come from there, not from `catch (e) => e.toString()` in widgets.

### Navigation — go_router

- One `GoRouter` in `src/routing/app_router.dart`, exposed as `goRouterProvider`
  (a Riverpod `Provider<GoRouter>`), consumed by `MaterialApp.router` in `app.dart`.
- Routes are named via `enum AppRoute { signIn, home, plan, planReview, tasks,
  settings }`; navigate with `context.goNamed(AppRoute.plan.name)` /
  `pushNamed`, never with string literals.
- Auth guard lives in `redirect`: unauthenticated → `/signIn`; authenticated on
  `/signIn` → `/`. `refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges())`
  so the guard re-runs on sign-in/out.
- Flows that interrupt (plan review, settings) are `pageBuilder` routes with
  `MaterialPage(fullscreenDialog: true)`. Deep-link-able things (a task by id)
  are nested routes with path parameters: `/tasks/:id`.
- `errorBuilder` → `NotFoundScreen`. No `Navigator.push` anywhere in features.

### Other mobile rules

- Riverpod only, with `riverpod_generator` + `riverpod_lint` (`custom_lint`
  enabled in `analysis_options.yaml`). Do not add another state-management or
  DI package.
- Networking: one Dio instance from `dioProvider` with an interceptor that
  attaches the Firebase ID token (`getIdToken()`) and force-refreshes it once on
  401. Only repositories use it.
- Reminders are scheduled locally with `flutter_local_notifications`; the server
  never sends reminder pushes in v0.1.
- Strings: user-facing Croatian in v0.1 via `flutter_localizations` + `app_hr.arb`;
  while a string has no key, mark it with `.hardcoded` so it is greppable later.
- Tests: unit tests for controllers, services and repositories with `mocktail`
  fakes; widget tests for each screen's loading/error/empty state; goldens only
  for the plan review screen. Test files mirror `lib/` under `test/`.

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
