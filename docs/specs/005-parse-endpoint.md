# 005 — Turning a sentence into tasks

The first endpoint that costs money per call. Spec 003 built the storage; this
fills it from Croatian prose.

## Endpoint

### `POST /parse` → 200

```json
{ "text": "sutra ustati u 7, nazvati Marka prije podne, harmonika 19:00-20:30",
  "timeZone": "Europe/Zagreb" }
```

```json
{ "tasks": [
    { "title": "Ustati", "date": "2026-09-29",
      "startsAt": "2026-09-29T05:00:00Z", "endsAt": null, "priority": "normal" },
    { "title": "Nazvati Marka", "date": "2026-09-29",
      "startsAt": null, "endsAt": "2026-09-29T10:00:00Z", "priority": "high" }
  ] }
```

The client shows these, the user fixes what is wrong, and `POST /plans` stores
the result. Same shape both ways, so the screen can hand back what it received.

## Why the model is not asked to call a tool

Older guides get structured output by defining a tool and forcing the model to
call it. That is no longer the way: the current API constrains the response
itself through `output_config.format`, and the TypeScript SDK exposes it as
`client.messages.parse()` with `zodOutputFormat(schema)` — the same Zod we
already use, and `response.parsed_output` comes back typed.

Shape is therefore guaranteed by the server. **Meaning is not**, which is why
the Zod schema below carries more than types.

## What the prompt gets

Per CLAUDE.md: the user's text, the IANA time zone, **and the current local
date and weekday computed from that zone**. Without the last part "sutra" has
no referent — the model would guess from its training cutoff.

Times come back as UTC instants; the model is told the offset explicitly rather
than left to infer it.

## Validation, and one retry

`parsed_output` is `null` when the response does not fit the schema. Beyond
shape, the schema also refuses what is structurally valid but wrong:

- `endsAt` before `startsAt`
- a `date` outside the plan's day
- an empty `title`
- `priority` outside the enum

On failure the call is made **once more**, with the validation error appended
as a correction. If the second attempt also fails, the request is
`502 {"error":{"code":"parser_failed"}}` — the model is a dependency, and a
dependency that will not answer usefully is a bad gateway, not our bug.

**Both attempts write an `ai_calls` row.** A retry costs money, and a row per
API call is what CLAUDE.md asks for.

## Limits

One user with a script must not be able to spend the Anthropic budget. Four
limits, shallowest first:

| where | limit | what it protects |
|---|---|---|
| request body | `text` at most **1000 characters** | the example in README is 66; a talkative plan maybe 400 |
| model call | `max_tokens: 1024` | a hard ceiling *before* Zod sees anything — the model cannot produce a $5 answer |
| response schema | at most **20 tasks** | a day does not have fifty obligations |
| per user | **50 `/parse` calls a day** → `429` | the only one that actually protects the bill |

The daily cap needs no new machinery — `ai_calls` already holds what it asks:

```sql
select count(*) from ai_calls
where user_id = $1 and created_at > now() - interval '1 day'
```

Retries count, because they cost.

## Understanding nothing is not an error

Someone types "bok", or a line of unrelated words. That returns **200 with an
empty `tasks` array**, not a 4xx: the request was well formed and the service
worked, it simply found no plan in the text.

The client then shows an example — which is the one moment where guidance
helps, because it was asked for rather than imposed. Teaching a format up front
would contradict the premise in README: *"Most task apps make you fill in
forms... Saidly meets that habit where it is: one text box."* The confirmation
screen, not a syntax, is how the user learns what the parser understood.

## `ai_calls`

Deferred in spec 001, needed now. Columns per CLAUDE.md: `provider`, `model`,
`tokens_in`, `tokens_out`, `cost_usd`, `latency_ms`, `user_id`, plus `id` and
`created_at`, indexed on `(user_id, created_at)`.

Cost is computed at write time from `src/llm/pricing.ts`, the only place prices
may live. See `docs/providers.md` for the numbers and for how they were
derived.

## `LlmProvider`

```ts
type LlmProvider = {
  readonly name: string;
  readonly model: string;
  parse(input: ParseInput): Promise<ParseResult>;  // tasks + usage
};
```

The provider returns tokens and latency alongside the tasks; writing the
`ai_calls` row is the service's job, not the provider's — otherwise every new
provider would have to remember to do it.

Tests use a fake provider: no network, no key, no cost. The Anthropic provider
gets a handful of tests of its own against recorded responses.

## Model

**Claude Haiku 4.5** to start, because `docs/providers.md` puts it at $1.15 per
thousand calls and the difference to Sonnet 5 is $34 a month at a thousand
users. That is a starting point rather than a verdict: the model is one
constant, and `pnpm eval` exists to replace the guess with a measurement.

## Decision: `/parse` stores nothing

It writes an `ai_calls` row and returns tasks. The plan row appears only when
the user confirms, through `POST /plans`.

The cost is real: a bad parse the user abandons leaves no trace of what they
typed, which is exactly the input worth having. The alternative — writing the
plan here and having confirmation attach tasks to it — would keep that, but it
changes an endpoint that already works and stores text for plans nobody wanted.
`eval/` is the answer for parser quality; production text is not a corpus.

Worth revisiting if bad parses turn out to be common and unreproducible.

## Out of scope

Gemini, `pnpm eval`, streaming, caching (a ~400-token request never reaches the
minimum cacheable prefix — see `docs/providers.md`), rate limiting.

## Done when

A Croatian sentence returns tasks with the right dates and times, the call is
recorded in `ai_calls` with its cost, a malformed model response is retried
once and then fails as a 502, and every test runs without a network.
