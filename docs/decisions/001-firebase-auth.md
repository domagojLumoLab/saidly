# 001 — Firebase Auth instead of Supabase Auth

**Date:** 2026-09-10 · **Status:** accepted

## Context
The API needs a hosted identity provider; the database is our own Postgres, so
only authentication is needed from a BaaS. The developer already knows Firebase
Auth from Flutter work.

## Decision
Use Firebase Authentication (Email/Password in v0.1). The API verifies the
Firebase ID token itself with `jose` against Google's JWKS; no Admin SDK.

## Alternatives considered
- Supabase Auth — equally simple, but free-tier projects pause after a week of
  inactivity, which bites a side project used a few evenings a week.
- Own auth — never for a one-person project.

## Consequences
One Firebase project covers auth now and Firebase AI Logic / Gemini Nano
fallback on Android later. Token verification logic is provider-specific but
isolated in one middleware.
