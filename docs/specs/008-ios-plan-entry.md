# 008 — Plan entry: a sentence in, reviewed tasks out, one plan stored

The first feature of the native client. Spec 007 proved the token; this one
uses it for what Saidly is for: the user writes tomorrow in one sentence,
`POST /parse` turns it into tasks, the user fixes what is wrong, and
`POST /plans` stores the result. The API side exists (specs 003 and 005); this
spec is iOS only.

The developer writes the Swift code (see `apps/ios/CLAUDE.md`). This spec says
what and why; the steps at the end say in which order.

## Scope

- `Networking` — the tests skipped in 007, a `post` with an `Encodable` body,
  one shared encoder and decoder, the API's error body mapped to `AppError`,
  and the token actor. `APIPlanRepository` with its DTOs.
- `Domain` — `PlanItem`, `PlanDraft`, `Priority`, the `PlanRepository`
  protocol, two new `AppError` cases.
- `PlanFeature` (new module) — `PlanEntryViewModel` and `PlanEntryView`,
  `PlanReviewViewModel` and `PlanReviewView`, a String Catalog.
- App target — `AppDependencies` builds `APIPlanRepository`; the signed-in root
  becomes the plan entry screen. `HomeView`, `HomeScreen`, `HomeViewModel` and
  `MeResponse` are deleted: they proved the chain and have no job left.

## The API, as the client sees it

`POST /parse` with `{ "text": "...", "timeZone": "Europe/Zagreb" }` answers

```json
{ "tasks": [
    { "title": "Ustati", "date": "2026-10-30",
      "startsAt": "2026-10-30T06:00:00.000Z", "endsAt": null, "priority": "normal" }
  ] }
```

`tasks` may be empty: "bok" contains no plan, and that is a 200, not an error.

`POST /plans` takes `{ date, timeZone, rawText, tasks: [{ title, startsAt?,
endsAt?, priority? }] }` with at least one task and answers 201 with the stored
plan. Errors from both arrive as `{ "error": { "code": "...", "message": "..." } }`.

## Decisions

- **The model is `PlanItem`, never `Task`.** `Task` is Swift Concurrency's; a
  type of ours with that name shadows it in every file that imports `Domain`.
- **DTOs live in `Networking` and map to `Domain`.** The wire shape (`date` per
  task, `null` vs absent, string priorities) is the API's business. Domain
  models carry what the screens need: `PlanItem` has a local `id: UUID` for
  list identity and editing, which the parse response does not have.
- **A calendar day is a `String` (`"2026-10-30"`), never a `Date`.** A `Date` is
  an instant. Decoding a day as midnight UTC and showing it in Zagreb is a
  classic off-by-one-day bug. The day is opaque to the client: received from
  `/parse`, sent back to `/plans`.
- **One plan per save, dated by the first item's day.** The parser resolves
  "sutra" to one day; a sentence that spans two days is saved under the first.
  Splitting it into two plans is out of scope.
- **Dates use one decoder and one encoder, owned by `APIClient`.** The API
  sends fractional seconds (`.000Z`); `JSONDecoder`'s built-in `.iso8601`
  strategy rejects them. The decoder accepts both forms, the encoder writes
  plain ISO 8601.
- **`nil` is omitted, not sent as `null`.** `POST /plans` declares the optional
  fields as optional, not nullable, and refuses `null`. Synthesised `Encodable`
  already omits `nil` optionals; nothing custom may change that.
- **Error codes, not statuses, pick the `AppError`.** `APIClient` decodes the
  error body when there is one and maps `rate_limited` → `.rateLimited`,
  `parser_failed` → `.parserFailed`. The status mapping from 007 stays as the
  fallback for bodies that do not decode.
- **The token actor makes concurrent 401s share one refresh.** Two requests
  that fail together must not force-refresh twice. `TokenStore` is an `actor`
  between `APIClient` and `TokenProvider`; while a refresh is in flight, other
  callers await the same `Task` instead of starting their own. This is the
  reentrancy case `apps/ios/CLAUDE.md` names.
- **Review is a sheet driven by optional state.** `PlanEntryViewModel` holds
  `draft: PlanDraft?`; the view presents `.sheet(item:)`. No router yet: there
  is one screen and one interruption. The router arrives with a second
  destination (009).
- **No service.** Saving touches one repository. `ConfirmPlanService` appears
  in 010, when confirming also schedules reminders.
- **`TimeZone.current.identifier` is read by the view model at the moment of
  the request**, not stored at launch: a user who travels gets the zone they
  are in.

## Errors

| Source | `AppError` | Shown as |
|---|---|---|
| 429 `rate_limited` | `.rateLimited` (new) | "You've planned a lot today. Try again tomorrow." |
| 502 `parser_failed` | `.parserFailed` (new) | "Couldn't understand that. Try rephrasing." |
| 400 `invalid_request` | `.unknown` | a bug on our side, not something the user can fix |
| `URLError`, 401, 5xx | as in 007 | as in 007 |

An empty parse result is not an error: the entry screen shows "No tasks found
in that text" and keeps the text so the user can edit it.

## Out of scope

Editing times in review (titles, priority and deletion only), splitting a
multi-day sentence, `GET /tasks` and the today screen (009), reminders (010),
voice input, offline drafts, the OpenAPI-generated client (v0.2).

## Done when

- `xcodebuild test -scheme Saidly` is green and CI's `apps/ios` job passes.
- Swift Testing tests cover:
  - `APIClient`: bearer header, decoding, 401 → refresh → retry, two 401s →
    `.sessionExpired`, `URLError` → `.networkUnavailable`, 5xx → `.server`,
    error body → `.rateLimited` / `.parserFailed`, a `post` body that omits
    `nil` fields, a date with fractional seconds.
  - `TokenStore`: two concurrent refreshes call the provider once.
  - `APIPlanRepository`: DTO ↔ Domain mapping, including an empty parse.
  - `PlanEntryViewModel` and `PlanReviewViewModel` with a `FakePlanRepository`:
    idle → loading → loaded / empty / failed, delete an item, save.
- `PlanEntryView` and `PlanReviewView` have previews for loading, loaded,
  empty and failed, built from the same fake.
- On a simulator against the local API: "sutra ustati u 7, harmonika
  19:00-20:30" shows two items with times in local time; renaming one, deleting
  nothing and saving answers 201; `GET /tasks?date=<that day>` with curl returns
  the two tasks.

## Steps (one session each, roughly)

1. `Networking`: the `APIClient` tests skipped in 007, with `FakeTokenProvider`
   and the existing `FakeHTTPTransport`.
2. `Networking`: shared encoder and decoder, `post`, error body → `AppError`;
   `Domain`: `.rateLimited`, `.parserFailed`. Tests first for each.
3. `Networking`: `TokenStore` and its concurrency test.
4. `Domain`: `PlanItem`, `PlanDraft`, `Priority`, `PlanRepository`;
   `Networking`: DTOs and `APIPlanRepository` with tests.
5. `PlanFeature`: `PlanEntryViewModel` with tests, `PlanEntryView` with
   previews; app: wire it as the signed-in root, delete the Home files.
6. `PlanFeature`: `PlanReviewViewModel` with tests, `PlanReviewView` as a sheet;
   String Catalog with English and Croatian.

## Then what

009 today's tasks (`GET /tasks`) and marking one done.
010 local notifications from the stored tasks; `ConfirmPlanService`.
