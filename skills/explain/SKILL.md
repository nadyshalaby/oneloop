---
name: explain
description: >-
  Explains logic short and plain: the problem, pseudocode, the effect, the risks. Use it whenever
  the user asks how code, a flow or a feature works, or asks you to explain a change before it is
  built, and at the loop's Scope step on every change, after the scope line and the note (the law).
---

# explain

A short, plain explanation of logic the user can take in at a glance: plain words and
pseudocode, never a report.

## Read first, run nothing, change nothing

Read just enough to get the logic right: files, searches and `git` history. Nothing is run to try
an idea (no scratch code, no experiments, no test runs), and nothing is edited or created here.
Inside the loop this comes right after the scope line and the note (the law's Scope step), and
the loop then goes on to Edit; no yes is waited for. Asked on its own, it ends the turn.

## Explaining a change before it is built

Write, in this order and short:

- **The problem.** What happens today and why it is wrong or missing, in two or three plain
  sentences.
- **What I'd build.** Pseudocode of the core logic only: what goes in, the decisions in order,
  what comes out. Comments mark what is unchanged, what is new and any switch that guards it.
- **Effect.** What changes for the user and in the code, in a line or two.
- **Risks.** What could go wrong for the user or in the code, or is given up, one line each.

The explanation is the text of your reply, sent before the next tool call; a plan inside your
thinking is not an explanation, the user never sees it.

Inside the loop, Edit follows at once. Asked on its own, stop here: the build, when the user
wants it, runs the loop (the always-on law), whose Scope step prints the scope line and the
note; an explanation already given for the same change stands and is not repeated.

## Explaining existing code

When the user asks how something works, write short: what it does in plain words, how it works
as pseudocode of the real flow in order, what it touches, and the gotchas. Nothing changes, and
no question follows.

## Keep it plain

- A screen, not a page; more depth only when the user asks for it.
- The user's own words and domain terms; no jargon, and no file paths or line numbers unless
  asked.
- Never about tests, reviews, specs or process, not even as a risk (a missing test setup
  included); the rules already cover those.
- Pseudocode reads like the logic: real names for the domain things, `IF`, `FOR`, `RETURN`, `←`
  for a value taken, `--` for a comment.

## Example

The problem. A coupon still applies after its end date, because checkout only checks that the
code exists.

```
FUNCTION applyCoupon(order, code)
  coupon ← the coupon with this code                   -- unchanged
  IF no coupon THEN RETURN order, "unknown code"       -- unchanged
  IF today is after coupon.endsOn THEN                 -- new
    RETURN order, "coupon expired"
  RETURN order with coupon.discount taken off          -- unchanged
END FUNCTION
```

Effect: expired coupons stop lowering prices at checkout; valid ones work as before.
Risk: an end date stored without a time zone could end the coupon a few hours early or late.
