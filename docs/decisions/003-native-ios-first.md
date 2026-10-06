# 003 — Native iOS client first, Flutter client paused

**Date:** 2026-10-06 · **Status:** accepted

## Context
v0.1 was planned with a Flutter client for iOS and Android. The Flutter shell
(sign in, sign out, a proven token — #16) works. But the features that make
Saidly worth using are native on iOS: on-device transcription (SpeechAnalyzer),
on-device parsing (Foundation Models), wake-up alarms (AlarmKit), App Intents
for Siri, a widget and a Live Activity. In Flutter every one of them is Swift
behind a platform channel, plus the bridge to maintain.

The project also exists to build the developer's senior iOS skills — Swift 6
concurrency, SwiftUI with Observation, modular architecture, Swift Testing.
At ~10 h/week a Flutter client plus a separate iOS practice app would split the
time in two.

## Decision
Build the v0.1 client as a native iOS app in `apps/ios` (Swift 6, SwiftUI,
iOS 26 minimum) and pause the Flutter client without deleting it.

- The API does not change. The iOS app is registered as a second iOS app in
  the same Firebase project, so ID tokens carry the same `aud` and `iss`.
- The native app uses its own bundle id (`com.lumolab.saidly`); the Flutter
  app keeps `com.lumolab.saidlyapp`, so both can be installed side by side.
- iOS 26 minimum because Foundation Models, SpeechAnalyzer and AlarmKit
  require it, and it removes `#available` branching from a new codebase.
- The Flutter client stays in the repository and in CI so it does not rot.

## Alternatives considered
- Flutter first, native features through platform channels — the native code
  gets written anyway, behind an extra layer, and the iOS-specific skills are
  practised second-hand.
- Both clients in parallel — not finishable at ~10 h/week.
- Delete the Flutter client — it works, costs nothing to keep, and is the
  starting point for Android later.

## Consequences
- No Android build until the Flutter client resumes. Acceptable for v0.1–v0.3:
  the app's first user is its developer.
- The API contract is now implemented by hand in Swift (and later again in
  Dart). Revisit in v0.2: generate an OpenAPI document from the Zod schemas and
  generate the Swift client from it.
- The App Intent path becomes simpler: an intent can call the same Swift
  parsing and scheduling code the app uses, without starting a Flutter engine.
- The planned Flutter package for Foundation Models becomes optional. If it is
  built, its native half is code the iOS app already has.
- Revisit when v0.3 ships: resume Flutter for Android, or not.
