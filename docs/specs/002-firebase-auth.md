# 002 — Firebase ID token verification

Implements docs/decisions/001-firebase-auth.md on the API side.

## Goal

Turn a Firebase ID token in the `Authorization` header into a `userId` that
routes can read, and reject everything else with 401.

## How

`jose` verifies the token against Google's JWKS at
`https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com`
(`createRemoteJWKSet` caches the keys and refetches on rotation). Checked:

| Claim | Must be |
|---|---|
| signature | valid for a current Google key, RS256 |
| `exp` | in the future |
| `aud` | `FIREBASE_PROJECT_ID` |
| `iss` | `https://securetoken.google.com/<FIREBASE_PROJECT_ID>` |
| `sub` | non-empty — this is the `userId` |

No Firebase Admin SDK. No user row in our database: `sub` travels as a string,
as decided in 001-task-storage.

## Scope

- `src/lib/auth.ts` — the verifier, with the key source injectable
- `src/middleware/` stays out of it: the middleware lives in `src/lib/` next to
  the other middleware, and puts `userId` on the Hono context
- `GET /me` → `{ userId }`, the first protected route, so the whole path can be
  checked with curl before the mobile app exists
- `/health` stays public

## Testability

The key source is a parameter, not a hard-coded URL. Tests generate an RS256
key pair, sign their own tokens and pass a local key set, so the real
verification path runs — no mocking of `jose`, no network, no Firebase project.

## Errors

Anything wrong is `UnauthorizedError` → `401 {"error":{"code":"unauthorized"}}`.
The reason (expired, wrong audience, bad signature) is logged with the request
id but never returned: a caller learns only that the token is not accepted.

## Out of scope

Sign-in, refresh, roles, rate limiting, storing users.

## Done when

Tests cover: valid token, missing header, malformed header, expired token,
wrong `aud`, wrong `iss`, signature from the wrong key. `GET /me` returns the
`sub` for a valid token and 401 otherwise.
