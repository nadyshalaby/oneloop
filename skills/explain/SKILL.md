---
name: engineering-rules:explain
description: >-
  Explains logic short and plain: the problem, pseudocode, the effect, the risks. Use it before
  changing anything for a new task (the law's logic-first gate: explain, then get a yes), and
  whenever the user asks how existing code, a flow or a feature works.
---

# explain

A short, plain explanation of logic the user can take in at a glance: plain words and
pseudocode, never a report.

## Read first, run nothing, change nothing

Read just enough to get the logic right: files, searches and `git` history. Nothing is run to try
an idea (no scratch code, no experiments, no test runs); that waits until after the user's yes.
Nothing is edited or created before it.

## Before a new task: the gate

Write, in this order and short:

- **The problem.** What happens today and why it is wrong or missing, in two or three plain
  sentences.
- **What I'd build.** Pseudocode of the core logic only: what goes in, the decisions in order,
  what comes out. Comments mark what is unchanged, what is new and any switch that guards it.
- **Effect.** What changes for the user and in the code, in a line or two.
- **Risks.** What could go wrong for the user or in the code, or is given up, one line each.

Then ask through `AskUserQuestion` whether this is the right logic, "Yes, build it
(Recommended)" first. Build nothing before a yes. An answer that changes the logic gets a new
explanation and a new ask, and so does a logic that has to change mid-task.

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
