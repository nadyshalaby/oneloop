---
paths:
  - "**/*.{ts,tsx,mts,cts,js,jsx,mjs,cjs,vue,svelte,astro}"
  - "**/*.{py,pyi,go,rs,java,kt,kts,scala,groovy,swift,m,mm,c,h,cc,cpp,cxx,hpp,cs,fs,rb,php}"
  - "**/*.{ex,exs,erl,hs,clj,dart,lua,r,R,jl,pl,pm,sh,bash,zsh,ps1,sql,sol,zig,tf,proto,graphql,gql}"
  - "**/*.{css,scss,sass,less,html}"
managed-by: engineering-rules install.sh, copied from law/engineering-code.md; change the repository and re-run it
---
# Engineering law: the code rules

Part of the engineering law, loaded the first time you read a code file; binds every line of code you
write. Long forms: `~/.claude/engineering-rules/references/01-always-on-law/`.

- **Production code**: every file that ships. Test files (`*.test.*`, `*.spec.*`, `*_test.*`, `*_spec.*`, `test_*`, anything under `tests/`, `__tests__/`, `test/`, `spec/`), generated files and migrations are exempt from the bans below, except that the suppression ban holds in tests too and the focused/skipped-test ban exists only for tests.
- **Domain code**: services, use-cases, repositories, business rules, validators, jobs, workers; not scripts, tests, CLI glue or presentation. **Hot path**: runs per request, render, row, job or frame, or in a loop over data-sized input. **UI-bearing**: any change to markup, styles, tokens, components, screens, layout, motion, UI copy or visual assets.

## 1.1 Caps, bans, one thing per file

**Caps.** At most 3 parameters (group more into a named type) and 3 levels of nesting (guard clauses, early returns).

**Bans in production code, zero tolerance:**
- No lint, type or coverage suppressions: `biome-ignore`, `eslint-disable`, `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck`, `istanbul ignore`, `c8 ignore`, `v8 ignore`, or another language's equivalent (9.5, 16.7). This one holds in tests too; the sole exception is `@ts-expect-error` over deliberately invalid test input, with a comment saying why.
- No non-null `!` assertions. No empty catches: `catch (e) {}`, a comment-only catch, `.catch(() => {})`, `except: pass`, an error discarded into `_`.
- No inline `interface` or `type` of 2+ properties in a router, service, middleware, guard, controller, component, page or route module; extract it to a `*.types` file in the feature's `types/` folder.
- No bare built-in error throws in domain code (`Error`, `TypeError`, `RangeError`, a `RuntimeException`, with or without `new`), no thrown literal, no `Promise.reject(new Error(...))`: throw a domain-specific exception subclass.
- No focused or skipped tests: `.only`, `fit`, `fdescribe`; `.skip`, `xit`, `xdescribe`, `test.todo` without a ticket or owner on the same line.
- No debug artifacts: no `debugger`, no `console.*` in domain code (log through the project's logger).

The code-rules hook warns when an edit adds one of these (its patterns: 9.5) and never blocks; the warning is this rule speaking: fix the line in the next edit, never route around it.

**One thing per file.** One component, one class (its private helpers with it) per file. Types in `*.types`, constants in `*.constants`, config in `*.config`, schemas in `*.schema`, style tokens and class maps in `*.styles`; single-use values stay inline. One documented folder skeleton per repository: read 2.3 before creating any file or folder. A technical exception cites the exact compiler or linter error it prevents.

**Names**, where the language, its frameworks and the codebase set no convention: `PascalCase` types, classes, interfaces (no `I` prefix), enums and UI components; `camelCase` functions, methods, variables and parameters, and `useCamelCase` hooks; `SCREAMING_SNAKE_CASE` enum members and true module constants (a computed default stays `camelCase`). Booleans start with `is`/`has`/`can`/`should`, functions with a verb; private fields use the language's own marker (a leading `_` only where it has none); a file's name and its primary export agree. Refused as a whole name: `data`, `info`, `item`, `obj`, `temp`, `val`, `res`, `result`, `handle`, `process`, `manager`, `helper`, `util(s)`, `base`, `core`, `MyThing`, `ThingImpl` or `AbstractThing` with one implementation, and any name that needs the body or a comment to explain it.

**Principles.** Build every unit so a second caller could import it as-is; extract on the second use, never speculatively. Before writing a function, type, constant, schema or component, search the repo for one that does it and paste the search that found none; the same 3+ lines twice: extract. Any shape with 2+ properties is a named type; one function does one thing; explicit over clever. Handle null, empty, concurrent and partial-failure paths. Leave nothing behind: a change deletes what it orphans (callee, import, type, constant, schema, fixture, flag, config key, env var, translation, test, doc line). Dead code that was there before your change is a follow-up, never part of this diff. Comments only for a non-obvious why.

**Clean-code floor (3.4).** 1 A function does or answers, never both. 2 No flag parameters: two functions or a named option. 3 Never mutate inputs; return a new value. 4 Fail fast at the boundary. 5 One level of abstraction per function. 6 Talk to what you hold: no `a.b().c().d()`. 7 Every error keeps its cause and context; never log-and-continue where the caller cannot proceed. 8 Every promise is awaited, returned or handled; no sleep standing in for a signal. 9 Composition before inheritance, no hierarchy deeper than two. 10 A closed set is a type (enum or union), never a bare string.

**Refuse on sight.** "Add error handling later"; a `TODO` with no owner; a fallback for a hypothetical requirement; a shim for code never deployed; a half-finished implementation; re-exports "for convenience"; a `// removed:` comment; commented-out code; a symbol your change left with zero references.

## 1.3 Performance guardrails (3.1)

1 Never query or call per loop item; batch. 2 Parallelize independent I/O, bounded. 3 Bound every result set: a LIMIT and keyset pagination over deep OFFSET. 4 Bound every cache with a TTL or LRU cap. 5 Bound every fan-out: a pool or chunks, never `Promise.all` over a data-sized list. 6 No sync blocking I/O on a server request path. 7 Filter on indexes: no function around an indexed column, no leading-wildcard LIKE on big tables. 8 No O(n²) on unbounded input: a Map or Set, loop invariants hoisted. 9 Batch bulk writes. 10 Stream large payloads. 11 Stable props and keys in UI hot paths: no inline object, array or lambda props to memoized children, no index keys on mutable lists, long lists virtualized. 12 Measure (profile, EXPLAIN) before optimizing.

## 1.6 Four principles (worked failures: 14.1)

- **Think before coding.** State assumptions; for an ambiguous ask list two readings and pick one with a reason; push back when a request collides with a cap, a prior decision or evidence; ask instead of guessing. Can you point at the line that authorized this code?
- **Simplicity first.** The minimum code for the stated problem: no speculative features, "while I'm here" extras, single-use abstractions, handling for impossible cases, or tuning knobs. Does the acceptance check still pass without this line?
- **Surgical changes.** Every changed line traces to the request; touch only the files the task names; no adjacent refactors; match the surrounding style; pre-existing bugs, smells and dead code become follow-ups, never hunks of this diff; clean every orphan your own diff made.
- **Goal-driven execution.** Every change is proven by a check you ran, machine checks first; a failing check stops you, and it is never loosened to pass.
