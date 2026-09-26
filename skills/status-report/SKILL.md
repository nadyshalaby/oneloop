---
name: status-report
description: Plain-language status report in one fixed layout — Doing, Done (every finished item tagged Shipped, Pushed not verified, or Local), then Todo — checked against git and the live system instead of guessed. Use whenever the user asks where things stand, even without the word report — status, status report, where are we, what's done, what's left, what are you working on, progress update, recap, what's live, is it shipped, is it pushed, did that go out — or types /status-report, and for every scheduled check-in brief. Nothing is called Shipped without a live check, and when a check is impossible the lower tag wins.
---

# Status report

The user wants one glance to answer three questions: what's moving, what's finished, and what's left. The part they care about most, and the part that is easiest to get wrong, is whether finished work has actually reached anyone. So every Done item carries a tag saying how far it got.

A report that says "done" when the work only exists on this laptop is worse than no report, because they act on it: they tell someone, stop watching, move on. The tags are claims about the real world, so check them. Never fill one in from memory or from what a note says.

## The layout

Three parts, always in this order (it is the order the 10-minute check-in has always used). In a full report each part is a bold header with a bullet list under it, one bullet per item:

```
**Doing**
- Wiring up the email step, the last test still fails

**Done**
- [Shipped] Checkout rounding fix, live and I checked the live site shows it
- [Pushed, not verified] Invoice export, on the main branch but the live site doesn't have it yet
- [Local] Email footer tweak, finished here but not pushed

**Todo**
- Move the old orders over
```

- **Doing** is what's in progress right now, plus anything you finished but haven't yet seen work. Finished-but-unproven is not Done.
- **Done** is finished and proven (a test passed, you watched it run). One tag per item, no item without a tag.
- **Todo** is what's left, including side findings you noticed but haven't chased.
- A part with nothing in it still gets its header, with one bullet: `- Nothing yet`. Never pad it. On a fresh session that is the honest report.
- The report is only these three parts. No intro line before Doing, no summary or sign-off after Todo, and no extra sections.
- Name each item by what it does, in a few plain words. No task numbers, ticket codes, list positions or commit hashes anywhere in the report, because the user reads these by meaning and a number means nothing to them.

## The three tags

- **[Shipped]** live where people actually use it, and you checked it there. Where that is depends on what the work is for: the real site for a site fix, the training copy for work meant for the training copy, an installed and updated plugin for a plugin, an upload that plays for a video, the file in use for a personal config. The check has to be yours: made this session, or a result already visible in the conversation. Say how you know in a few plain words on the item ("live, I checked the live site").
- **[Pushed, not verified]** it is on the remote (pushed or merged) but nobody has checked it live. Add a few words on where it stands and what it still needs: "on its own branch, needs a merge", "merged, needs a deploy", "deployed, haven't looked yet". If you did check and the live side doesn't have it, this is still the tag, and the words say so ("I checked and the live site doesn't have it yet, needs a deploy").
- **[Local]** not even pushed: finished edits that aren't committed, commits that exist only on this machine, files that never left it.

Work with no git remote (a change made on a server over ssh, a config edit, a render) follows the same ladder by meaning: still only here or not sent anywhere is Local, sent to its destination but unchecked is Pushed, not verified, checked working at its destination is Shipped.

## Finding the truth

Notes, commit messages, PR titles and earlier messages say "deployed" when someone hoped it was. Treat them as claims to test, not as checks.

1. **What's happening.** Read the task list (TaskList), the repository's `TODO.md` checklist (an open `[ ]` or `[~]` line is Doing or Todo; a `[x]` line is a Done candidate, still to be tagged) and the conversation for Doing, Done and Todo. If the task list disagrees with reality, fix it with TaskUpdate while you're here.
2. **Local versus pushed**, in every repo the work touched:
   ```
   git status --short --branch                      # unfinished edits, ahead/behind
   git log --branches --not --remotes --oneline     # commits that exist only here
   git branch -r --contains <commit>                # is this one on a remote, and which branch
   ```
   No remote configured means nothing has been pushed, so it is Local.
3. **Shipped.** Find how this project says "live" gets checked (its CLAUDE.md, README, deploy notes) and run that check. Compare what is live against the thing you're claiming, the right version or the right behavior, not just "the site answers".
4. **Can't check** (no network, no access, no known check)? Tag at the level you can prove and say in a few words what you couldn't check. Don't round up.

When unsure, go lower. A wrong Shipped makes the user stop watching or tell a customer; a modest tag costs them a five-second question.

## Two sizes

**Full report** is the default for any ask, including ones that just say "quick" ("quick status", "quick one, where are we"). One line per item, merge small related items, and stop after Todo.

**Quick brief** is only for the 10-minute check-in, or when the user asks for a brief. It is the same three parts squeezed into three bullets, so it still reads as a list and still matches the full layout:

```
- **Doing:** what's in progress right now
- **Done:**
  - [Shipped] one thing that finished since the last report
  - [Local] another one
- **Todo:** what's left
```

Three top-level bullets, labels in bold. A part with a single item keeps it on the label line (`- **Doing:** wiring up the email step`). A part with several items gets one sub-bullet per item, so a busy check-in still reads as a list and every tag sits at the start of its own line. No headers and no deeper nesting. Items follow the same wording rule as in the full report: say in plain words what it is and, for anything not fully live, what is still missing ("on the main branch now, but I checked and the live site doesn't have it yet (needs a deploy)").

Only things finished since the last report go in Done, with one exception: an item whose tag moved up since last time (Local to Pushed, Pushed to Shipped) is listed again with its new tag, because that is the news. If nothing changed at all, write one line: `No change, still on <thing>`.

## Wording

- Casual everyday English, short lines, the way you'd tell a friend. Skip words like HEAD, upstream, "ahead by 2", SHA.
- No technical section of any kind. The user has said so more than once, and firmly: no "Technical details", no "Sources" or "How I checked" block, no closing list of commands, hashes, branch names or file paths, and none of that scattered through the items either. They read a report for what is true, not for how you found out. Plain phrases like "the main branch" or "its own branch" are fine, raw names like origin/main are not. When a tag needs a reason, put it on the item in a few plain words ("live, I checked the live site", "on the main branch but the live site doesn't have it yet", "committed here, not pushed"). Your checks stay in your own work, so if they ask for proof you have it.

## After the report

A report is a snapshot, not a stopping point. Keep the task list in step with what you just said and carry on with the work, unless the user asked for the report in order to wrap up.
