# apps/ios — working rules for the native iOS client

Read together with the root `CLAUDE.md` (product, API contract, workflow).

## Who writes the code here

**The developer writes the Swift code in this folder himself.** It is how he is
building senior-level iOS skills, and that matters more than speed. Agents
working here:

- explain concepts, trade-offs and the "why", and point to the WWDC session or
  documentation page that covers it;
- give hints in escalating steps — a question, then the shape of the solution
  (types, responsibilities, where things live), then a sketch — and wait between
  steps;
- review code he has written like a senior colleague: what is good, what is a
  bug, what an interviewer would ask about, what Swift 6 will complain about;
- **do not create or edit `.swift` files, the Xcode project or `Package.swift`
  unless he explicitly asks for the code to be written.** Docs, specs, CI and
  config outside Swift sources are fine on request.

## Stack

- Xcode 26, Swift 6 language mode, **iOS 26 minimum** (`docs/decisions/003`).
- SwiftUI with Observation (`@Observable`). UIKit only where SwiftUI has no
  answer, wrapped in a `UIViewRepresentable`.
- Swift Testing (`@Test`, `#expect`). XCTest only for UI tests, if ever.
- Dependencies: `FirebaseAuth` from `firebase-ios-sdk` via SPM — the only one.
  No networking, DI, state-management or mocking libraries. No Combine in new
  code; `AsyncSequence` covers streams.

## Commands

```bash
# from apps/ios
xcodebuild test -scheme Saidly \
  -destination 'platform=iOS Simulator,name=iPhone 17'   # build + all tests
swift format lint --strict --recursive Saidly Packages   # formatting and lints
swift format --in-place --recursive Saidly Packages      # fix formatting
```

## Layout

```
apps/ios/
├── Saidly.xcodeproj
├── Saidly/                       # app target — thin
│   ├── SaidlyApp.swift           # @main; builds AppDependencies, picks the root view
│   ├── AppDependencies.swift     # composition root: the only place concrete types meet
│   ├── Config/                   # Debug.xcconfig, Release.xcconfig (API_BASE_URL)
│   ├── Resources/                # Assets.xcassets, Localizable.xcstrings (en + hr)
│   └── GoogleService-Info.plist  # committed — see docs/decisions/002
├── SaidlyTests/                  # app-level smoke tests only
└── Packages/SaidlyKit/           # local Swift package — where the code lives
    ├── Package.swift
    ├── Sources/
    │   ├── Domain/               # models + repository protocols; imports only Foundation
    │   ├── Networking/           # APIClient, endpoints, DTOs, API*Repository
    │   ├── Auth/                 # FirebaseAuthRepository — the only module importing Firebase
    │   ├── AuthFeature/          # sign in / sign out screens + view models
    │   ├── PlanFeature/          # enter text → parsed plan → confirm (the core feature)
    │   ├── TasksFeature/         # today's tasks, mark done
    │   └── Reminders/            # UNUserNotificationCenter scheduling
    └── Tests/                    # one test target per module, mirroring Sources/
```

Create a module only when it has content. A feature is a functional
requirement ("plan tomorrow", "get reminded"), not a screen.

## Architecture rules

### Dependencies point one way

```
Saidly (app) ──► Features ──► Domain ◄── Networking, Auth, Reminders
      └─────────────── wires concrete types ───────────────┘
```

- **Domain** holds immutable `struct` models (`Plan`, `PlanItem`, `AppUser`),
  `AppError`, and the repository protocols (`PlanRepository`,
  `AuthRepository`). It imports nothing but Foundation. Models are `Sendable`,
  `Equatable`, and `Codable` only if the API shape matches; otherwise the DTO in
  Networking maps to them.
- **Never name a model `Task`** — it collides with Swift Concurrency's `Task`.
  The API's tasks are `PlanItem` here.
- **Networking / Auth / Reminders** implement Domain protocols and translate
  low-level errors (`URLError`, Firebase `AuthErrorCode`, HTTP status) into
  `AppError`. Nothing else imports Firebase or touches `URLSession`.
- **Feature modules** import Domain only. They never see a concrete repository.
- **The app target** builds `AppDependencies` once in `SaidlyApp` and hands each
  feature what it needs. It contains no business logic.

### Presentation

- Views are small and dumb: they read view-model state and call its methods.
- One view model per screen: `@Observable @MainActor final class
  PlanViewModel`. Dependencies come in through `init` as protocols.
- Async state is an explicit enum, not a pile of booleans:
  `enum Loadable<Value> { case idle, loading, loaded(Value), failed(AppError) }`.
  Every list has an empty state; every failure has a retry.
- Start async work from `.task { }` so it is cancelled with the view; avoid
  bare `Task { }` in views.
- User-facing error text comes from `AppError`, never from
  `error.localizedDescription` of a lower layer.

### Navigation

- The root view switches on auth state: signed out → `SignInView`, signed in →
  the main `NavigationStack`. No manual "push after login".
- Each stack's path lives in a small `@Observable` router with a `Hashable`
  `Route` enum; navigation is `router.path.append(.planReview(plan))`.
- Interrupting flows (plan review, settings) are sheets or
  `.fullScreenCover`, driven by optional state, not by booleans plus a payload.

### Dependency injection

- Constructor injection everywhere. SwiftUI `@Environment` with a custom
  `@Entry` only for things almost every view needs (e.g. the router).
- No singletons of our own, no service locator, no DI framework.
- Tests and previews use hand-written fakes that conform to the Domain
  protocols (`FakePlanRepository`), kept in each module's test target or a
  `*TestSupport` target when shared.

### Concurrency (Swift 6)

- Swift 6 language mode with complete checking, in the app and every package
  target. The app target uses **Default Actor Isolation = MainActor**;
  packages stay nonisolated by default and mark UI types `@MainActor`.
- Shared mutable state lives in an `actor`. The canonical case: the token
  provider that makes concurrent 401s wait for **one** refresh instead of
  starting several.
- Not allowed without a written reason in the PR: `@unchecked Sendable`,
  `nonisolated(unsafe)`, `Task.detached`, `DispatchQueue`, completion
  handlers in new APIs, `@preconcurrency import`.
- Respect cancellation: long work checks `Task.isCancelled` or uses cancelling
  APIs; a cancelled request is not an error to show.

### Networking

- One `APIClient` on `URLSession` with `async/await`. It builds requests from
  typed endpoints, attaches the Firebase ID token, force-refreshes once on 401
  and retries once, and decodes with a shared `JSONDecoder` (ISO 8601 dates).
- `API_BASE_URL` comes from the build configuration's `.xcconfig` (Debug →
  local or Railway, Release → Railway), read via `Info.plist`. Never hard-coded.
- Requests that depend on "today" send `TimeZone.current.identifier`.
- v0.2: the hand-written DTOs are replaced by a client generated from the API's
  OpenAPI document (`swift-openapi-generator`).

### Reminders

- v0.1: local notifications through `UNUserNotificationCenter`, behind a
  `ReminderScheduler` protocol in Domain. AlarmKit for wake-up alarms is v0.4.

### Strings

- String Catalog (`Localizable.xcstrings`), English first, Croatian alongside.
  Packages that show text have their own catalog and use `bundle: .module`.

### Tests

- Every view model and repository has Swift Testing tests in its module's test
  target. Test behaviour through the public API: given a fake repository that
  returns X, the view model ends in state Y.
- Networking is tested with a `URLProtocol` stub — no real network in tests.
- Async tests use `async` test functions; no sleeps, no expectations with
  timeouts.
- Previews are part of the work: every screen has previews for loading,
  loaded, empty and failed, built from the same fakes.

## Do not

- Do not add a second third-party dependency without a decision in
  `docs/decisions/`.
- Do not put logic in the app target or Firebase imports outside `Auth`.
- Do not silence a Swift 6 concurrency error to make the build pass — fix the
  isolation or ask.
- Do not write Swift code here unprompted (see the top of this file).
