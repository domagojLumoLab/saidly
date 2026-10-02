# 006 — The app shell: bootstrap, routing, sign-in

First Flutter work. `apps/mobile` is empty, so this spec covers the frame the
other screens hang on and nothing else: an app that starts, knows whether
somebody is signed in, sends them to the right screen, and proves the token it
holds is one the API accepts.

Deliberately boring. No plan entry, no parser, no notifications. Those are
specs 007–009; this one ends when a signed-in user sees an empty home screen
with their own email on it.

## Scope

- `main.dart` — `ProviderScope`, error handlers, `runApp`. Bootstrap only.
- `src/app.dart` — `MaterialApp.router` wired to `goRouterProvider`.
- `features/authentication/` — `AuthRepository` wrapping `firebase_auth`,
  `AppUser` domain model, sign-in screen and its controller.
- `src/routing/app_router.dart` — `AppRoute` enum, the redirect guard,
  `GoRouterRefreshStream`, `NotFoundScreen`.
- `src/exceptions/` — `AppException` sealed class, the first few subclasses.
- `data/` Dio setup: `dioProvider` with the ID-token interceptor.
- One screen behind the guard that calls `GET /me` and shows what comes back.

## Decisions

- **Email and password, not Google Sign-In.** One `firebase_auth` call, no
  platform configuration, no OAuth consent screen, and it works in the
  simulator on the first run. Social sign-in is a v0.2 question; the
  `AuthRepository` interface does not change when it arrives.
- **`GET /me` is the acceptance test, not a plan.** It is the one route that
  needs nothing but a valid token, and it answers `{ "userId": "<sub>" }` —
  no email, nothing else. The assertion is that this `userId` equals the uid
  firebase_auth gave the app locally. That equality proves the whole chain:
  Firebase issues the token, the interceptor attaches it, `jose` verifies it
  against Google's JWKS, `sub` becomes a userId. If that holds, every other
  route is plumbing.
- **The guard lives only in `redirect`.** No screen checks auth for itself.
  `refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges())`
  so signing out moves the user without anybody calling `go`.
- **English is the template language, Croatian is the translation.**
  `app_en.arb` is the template ARB, `app_hr.arb` sits beside it from the first
  commit so it never becomes a retrofit — a translation added later is a
  translation never added.
- **No `application/` layer yet.** Nothing in this spec spans two
  repositories. A `AuthService` that forwards to `AuthRepository` would be
  deleted at review, per the layer rules.
- **The interceptor force-refreshes once on 401 and retries, then gives up.**
  A second 401 means the token is not the problem.

## Errors

`AuthRepository` catches `FirebaseAuthException` and throws `AppException`
subclasses — wrong password, unknown user, network down, weak password. The
sign-in screen shows them through
`ref.listen(controllerProvider, (_, s) => s.showAlertDialogOnError(context))`.
No widget calls `e.toString()`.

## Out of scope

Plan entry, `POST /parse`, `POST /plans`, `GET /tasks`, notifications, the
tasks list, settings, password reset, account deletion, goldens, theming
beyond `ColorScheme.fromSeed`.

## Done when

- `flutter analyze` and `dart run custom_lint` are clean.
- Widget tests cover the sign-in screen's loading, error and empty states.
- Unit tests cover `AuthRepository` and the sign-in controller with `mocktail`.
- A router test asserts the guard both ways: signed out on `/` lands on
  `/signIn`, signed in on `/signIn` lands on `/`.
- On a simulator, signing in with a real Firebase account reaches a home
  screen that shows the local email and the `userId` returned by `GET /me`
  from Railway, and the two uids match.

## Then what

007 plan entry → `POST /parse` → review screen → `POST /plans`.
008 today's tasks and marking one done.
009 local notifications from the stored tasks.
