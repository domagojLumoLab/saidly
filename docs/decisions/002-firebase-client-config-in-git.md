# 002 — Firebase client config is committed, despite the "no API keys" rule

**Date:** 2026-10-01 · **Status:** accepted, applied 2026-10-02

> This reverses a rule from the initial commit (5823661, 2026-09-10), which
> ignored these three paths with the note "keep it out until the app is
> public". That threshold was wrong — see below — and the ignore lines were
> removed once the reversal was agreed knowing what it replaced.

## Context
`flutterfire configure` generated three files for `apps/mobile`:

```
lib/firebase_options.dart          apiKey, appId, projectId, messagingSenderId
ios/Runner/GoogleService-Info.plist      the same values, for the iOS SDK
android/app/google-services.json         the same values, for the Gradle plugin
```

Each contains a string called `apiKey`. CLAUDE.md says, without qualification,
"Do not commit secrets, `.env` files or API keys." Taken literally that forbids
these files — and without them the app does not build, because
`Firebase.initializeApp()` reads `firebase_options.dart` before any network
call and the native SDKs read the other two at build time.

## Decision
Commit all three, and add an explicit exception to CLAUDE.md naming them.

A Firebase client `apiKey` is not a credential. It identifies which Firebase
project a request belongs to; it authorises nothing. Google documents this
directly: these keys "are not used to control access to backend resources".
Access is decided by the ID token, and on our side by the API verifying that
token with `jose` against Google's JWKS, checking `exp`, `aud` and `iss`.

The decisive argument is that keeping the files out of git protects nothing.
The key is compiled into every shipped binary. Anyone can `unzip` an `.ipa` or
`.apk` and read it in under a minute. Git is not where the exposure is.

## Alternatives considered
- **Gitignore them and inject from CI secrets.** Adds three secrets to manage,
  breaks `git clone && flutter run` for any new machine, and hides the values
  from review while publishing them in every build. Cost without benefit.
- **Fetch the config from our API at startup.** Firebase needs it before it can
  make any call, so there is nothing to fetch it with. Not possible.
- **A second Firebase project for development.** Worth doing when there are
  real users to keep apart from test data. Today there are none, and a second
  project doubles the configuration for no current gain. Revisit before launch.

## Consequences
- CLAUDE.md gains one named exception. Everything else the rule covers —
  `ANTHROPIC_API_KEY`, `DATABASE_URL`, Sentry DSN in `.env` — stays absolute.
  The distinction to apply: a value that is shipped to every user is public by
  construction; a value the server holds is not.
- **The real exposure is account creation, not reading data.** With the key
  anyone can call Firebase Auth's `signUp` endpoint for this project and make
  accounts. That is true whether or not the file is in git. If it is abused,
  the answer is Firebase App Check, disabling self-service sign-up, or a
  quota — not hiding the key.
- **Follow-up worth doing:** these are Google Cloud API keys and can be
  restricted. Restricting them to the Identity Toolkit API in the Google Cloud
  console removes the possibility of using them against other Google APIs
  billed to the project. Not required for v0.1; cheap to do.
- Rotating is possible from the console if it is ever needed, and means
  regenerating these files and shipping an app update.
