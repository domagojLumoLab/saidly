# Parser provider costs

What one extraction call costs. The figures below are **measured**, not
estimated — the estimates this file used to carry were out by more than double.

Prices checked **2026-09-25** against
[claude.com/pricing](https://claude.com/pricing) and
[ai.google.dev/gemini-api/docs/pricing](https://ai.google.dev/gemini-api/docs/pricing).
Token counts measured **2026-09-28** against the real prompt in
`src/llm/anthropic-provider.ts`, on Claude Haiku 4.5.

## Measured

| sentence | chars | in | out | per call | per 1000 | latency |
|---|---|---|---|---|---|---|
| `sutra ustati u 7` | 16 | 1517 | 52 | $0.001777 | **$1.78** | 1.8 s |
| four tasks, the README example | 79 | 1543 | 190 | $0.002493 | **$2.49** | 2.0 s |
| eight tasks, a full day | 174 | 1591 | 388 | $0.003531 | **$3.53** | 3.4 s |

## What those numbers say

**Input is almost fixed.** Ten times more text moved it from 1517 to 1591 — the
user's sentence is roughly half a token per character, and everything else is
the system prompt plus the JSON schema the SDK sends as the response format.
About **1500 tokens of every call are ours, not the user's**.

**Output scales with tasks**, at roughly 48 tokens each.

**The old estimate of 400 input tokens was wrong by nearly 4×**, and the
conclusion drawn from it — $1.15 per thousand — understated the real $2.49 by
more than half. The estimate counted the prompt and forgot that
`zodOutputFormat` expands the schema into a much longer JSON Schema document.

**Two seconds is a long time to stare at a spinner.** The confirmation screen
needs to say what is happening, not just spin.

## Prices, for the arithmetic

| Model | in $/MTok | out $/MTok | cache read | cache write |
|---|---|---|---|---|
| Claude Haiku 4.5 | 1.00 | 5.00 | 0.10 | 1.25 |
| Claude Sonnet 5 | 2.00 | 10.00 | 0.20 | 2.50 |
| Gemini 2.5 Flash | 0.30 | 2.50 | — | — |
| Gemini 3.8 Flash | 0.75 | 3.75 | — | — |

Gemini 3.8 Flash is on promotional pricing until **2026-12-31**; from
2027-01-01 it doubles to $1.50/$7.50.

## What it costs in practice

A user who writes one plan a day makes ~30 calls a month. On Haiku, at the
measured $2.49 per thousand:

| | per month |
|---|---|
| 1 user | $0.07 |
| 1 000 users | $75 |
| 10 000 users | $747 |

Still small enough that parsing quality outweighs parsing cost — but no longer
so small that it can be ignored at ten thousand users.

## Caching: impossible on Haiku, possible on Sonnet

The earlier note here said caching could never apply because the request was
too short. That was based on the wrong token count. The real prefix is ~1500
tokens, and the minimum cacheable prefix is **model-dependent**:

| Model | minimum | our ~1500-token prefix |
|---|---|---|
| Claude Haiku 4.5 | 4096 | **will not cache** — silently, with no error |
| Claude Sonnet 5 | 1024 | would cache |

Which produces an odd result. Per thousand calls, with the fixed prefix served
from cache:

```
Haiku 4.5, no caching possible     1.543 × $1  + 0.190 × $5   = $2.49
Sonnet 5, uncached                 1.543 × $2  + 0.190 × $10  = $4.99
Sonnet 5, prefix cached            1.5 × $0.20 + 0.043 × $2 + 0.190 × $10 = $2.29
```

**Cached Sonnet costs about the same as uncached Haiku** — which removes cost
as an argument for choosing the weaker model, if the cache is warm. It is warm
only within the 5-minute window after a write, so this holds under steady
traffic and not for the first user of the evening; a cold write costs $2.50/MTok
and would make it worse. Worth measuring against `usage.cache_read_input_tokens`
before believing it.

**The cheaper lever, on any model, is a shorter prompt.** 1500 fixed tokens for
this task is a lot, and most of it is schema. Halving it halves the input cost
everywhere, with no caching machinery and no model change.

## For v0.1

Stay on **Claude Haiku 4.5**. `pnpm eval` is what decides whether it is good
enough at Croatian; if it is not, the Sonnet arithmetic above says the switch
costs less than it appears.

These numbers go into `src/llm/pricing.ts`, the only place prices may live, and
`ai_calls` stores the cost per call — so a stale price there silently corrupts
every row written after it.
