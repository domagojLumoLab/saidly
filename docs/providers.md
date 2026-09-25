# Parser provider costs

What one extraction call costs, so the number is known before the code is
written and not discovered on a bill.

Prices checked **2026-09-25** against
[claude.com/pricing](https://claude.com/pricing) and
[ai.google.dev/gemini-api/docs/pricing](https://ai.google.dev/gemini-api/docs/pricing).
Both change; re-check before quoting.

## The assumption

One call turns a few sentences into a list of tasks: **~400 input tokens**
(system prompt, the priority enum, the output schema, the user's sentence, the
local date and time zone) and **~150 output tokens** (three or four tasks as
JSON).

A thousand calls is therefore **0.4M input and 0.15M output tokens**, and

```
cost per 1000 calls = 0.4 × input$/MTok + 0.15 × output$/MTok
```

## The numbers

| Model | in $/MTok | out $/MTok | **per 1000 calls** |
|---|---|---|---|
| Gemini 2.5 Flash-Lite | 0.10 | 0.40 | **$0.10** |
| Gemini 2.5 Flash | 0.30 | 2.50 | **$0.50** |
| Gemini 3.8 Flash | 0.75 | 3.75 | **$0.86** |
| **Claude Haiku 4.5** | 1.00 | 5.00 | **$1.15** |
| Claude Sonnet 5 | 2.00 | 10.00 | **$2.30** |
| Claude Opus 5.5 | 4.00 | 20.00 | **$4.60** |

Gemini 3.8 Flash is on promotional pricing until **2026-12-31**; from
2027-01-01 it doubles to $1.50/$7.50, which is **$1.73 per 1000** — more than
Haiku. Worth knowing before building on the cheaper number.

The one to remember: **Haiku is about a dollar per thousand plans.**

## What that means for the product

A user who writes one plan a day makes ~30 calls a month.

| | Haiku 4.5 | Sonnet 5 |
|---|---|---|
| 1 user | $0.03 / month | $0.07 / month |
| 1 000 users | $35 / month | $69 / month |
| 10 000 users | $345 / month | $690 / month |

At a plausible subscription price this is a rounding error per user, which is
the useful conclusion: **parsing quality is worth more than parsing cost.** The
cheapest model is not automatically the right one, and the difference between
Haiku and Sonnet at 1 000 users is the price of a lunch.

## Caching does not help here

Prompt caching needs a stable prefix of 1 024–4 096 tokens depending on the
model. Our whole request is ~400. Even though the system prompt is identical on
every call, it is too short to cache — a fact worth knowing before spending an
evening on it.

If the prompt grows past that (few-shot examples would do it), caching becomes
worth measuring: cached input reads at $0.10/MTok on Haiku against $1.00.

## For v0.1

Start with **Claude Haiku 4.5**. Cheap enough not to matter, and the whole
point of `LlmProvider` plus `pnpm eval` is that this stays a measurement rather
than an opinion: if Haiku's Croatian time expressions turn out worse than
Sonnet's, the eval will show it and the swap is one line.

These are the numbers that go into `src/llm/pricing.ts`, which is the only
place prices may live — and note that `ai_calls` stores the cost per call, so a
stale price there silently corrupts every row written after it.
