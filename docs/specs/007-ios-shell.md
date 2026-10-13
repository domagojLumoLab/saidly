# 007 — The iOS shell: sign in, sign out, and a proven token

The native counterpart of `006-mobile-shell`, after `docs/decisions/003`. The
Xcode project, `SaidlyKit` with `Domain` and `Auth`, and `FirebaseSetup` exist
already. This spec covers the frame the other screens hang on and nothing
else: an app that knows whether somebody is signed in, shows the right screen,
and proves the token it holds is one the API accepts.

The developer writes the Swift code (see `apps/ios/CLAUDE.md`). This spec says
what and why; the steps at the end say in which order.

## Scope

- `Domain` — `AppError`, the `AuthRepository` protocol, `AppUser` (exists).
- `Auth` — `FirebaseAuthRepository`, the only type that imports `FirebaseAuth`.
- `AuthFeature` (new module) — `SessionModel` (who is signed in, for the root
  view), `SignInViewModel` and `SignInView`.
- `Networking` (new module) — the smallest `APIClient` that attaches the ID
  token and calls `GET /me`.
- App target — `AppDependencies` (composition root), `RootView` that switches
  on the session, `HomeView` showing the local email, the uid from `GET /me`,
  and a sign-out button.

## Decisions

- **Email and password only**, as in 006. The `AuthRepository` protocol does
  not change when Sign in with Apple arrives.
- **Auth state is an `AsyncStream<AppUser?>`.** `FirebaseAuthRepository` wraps
  `addStateDidChangeListener` in an `AsyncStream` and removes the listener in
  `onTermination`. No Combine, no delegate, no closure stored by the caller.
- **The root view switches on `SessionModel`; no screen checks auth itself.**
  Signing out moves the user to `SignInView` because the stream emits `nil`,
  not because a button navigates.
- **`GET /me` is the acceptance test.** It answers `{ "userId": "<sub>" }`.
  The uid it returns must equal the uid Firebase gave the app. That equality
  proves the chain: Firebase issues the token, `APIClient` attaches it, the API
  verifies it, `sub` becomes the userId.
- **Token handling is deliberately minimal here**: fetch the ID token, attach
  it, on a 401 force-refresh once and retry once. The `actor` that makes
  concurrent 401s share a single refresh is spec 008's first step, when there
  is more than one request to race.
- **`API_BASE_URL` comes from an `.xcconfig` per build configuration**, read
  through `Info.plist`. Debug may point at Railway until a local API is needed.
- **No service layer yet.** Nothing here spans two repositories.

## Errors

`FirebaseAuthRepository` maps Firebase `AuthErrorCode` to `AppError` — wrong
password or unknown user (one case, so the screen does not reveal which),
invalid email, network unavailable, unknown. `APIClient` maps `URLError` and
HTTP status to `AppError`. Views show `AppError`'s own message; nothing calls
`localizedDescription` of a lower layer.

## Out of scope

Plan entry, `POST /parse`, tasks, reminders, registration UI (create the test
user in the Firebase console), password reset, Sign in with Apple, theming,
the shared-refresh token actor (008).

## Done when

- `xcodebuild test -scheme Saidly` is green; `swift format lint` is clean.
- Swift Testing tests cover `SignInViewModel` (idle → loading → loaded/failed,
  with a `FakeAuthRepository`), `SessionModel` (follows the stream), and the
  `AuthErrorCode` → `AppError` mapping.
- `SignInView` has previews for idle, loading and failed.
- On a simulator, signing in with the console-created user shows the home
  screen with the local email and the `userId` from `GET /me` on Railway, and
  the two uids match. Signing out returns to the sign-in screen.

## Steps (one session each, roughly)

1. `Domain`: `AppError` and the `AuthRepository` protocol.
2. `Auth`: `FirebaseAuthRepository` — sign in, sign out, the auth-state stream.
3. `AuthFeature`: `SignInViewModel` with tests, then `SignInView` with previews.
4. `AuthFeature`: `SessionModel`; app: `AppDependencies` and `RootView`.
5. `Networking`: `APIClient` and `GET /me`; app: `HomeView`.

## Then what

008 the token actor, plan entry → `POST /parse` → review screen.
009 today's tasks and marking one done.
010 local notifications from the stored tasks.
