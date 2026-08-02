---
name: mutation-php-package
description: Use when raising mutation-testing coverage / MSI of a rasuvaeff/* PHP package, killing surviving mutants, or setting the Infection minMsi gate. Triggers on "raise MSI", "mutation testing", "kill mutants", "minMsi", "подними mutation", "minMsi 100", "infection".
---

# Mutation-harden a PHP Package

Raise a package's Infection MSI: kill every killable mutant with targeted tests,
classify the rest as equivalent/timing/tooling, and set `minMsi` honestly.

`composer build` does NOT run mutation — it's a separate gate. Read the package's
own `AGENTS.md` first.

## 0. Build the coverage image (once)

`composer:2` has no pcov/intl — `composer mutation` fails there. Build
`composer-pcov:local` once (recipe in the **build-php-package** skill). Run from
the package root.

## 1. Baseline

```bash
docker run --rm -v "$PWD":/app -w /app --entrypoint composer composer-pcov:local \
  mutation 2>/tmp/mut.log
```

The achieved MSI and the survivor list (with diffs) land on **stderr**
(`/tmp/mut.log`). Infection emits a flood of `Deprecated: SplObjectStorage` lines
on PHP 8.5 — filter them: `grep -vF SplObjectStorage /tmp/mut.log | grep -vF Deprecated:`.

Three survivor buckets in the text log:
- **Escaped** — covered but not detected (a test runs the line but doesn't assert
  the mutated behavior). Fixable by a better assertion.
- **Not Covered** — no test exercises the line at all. Add a test that reaches it.
- **Timed Out** — usually an infinite loop introduced by the mutant (often a
  timing/polling method).

MSI formula: `(killed + timedOut + errors) / totalGenerated`. `Covered MSI`
excludes the not-covered bucket.

## 2. Iterate per class

Fast loop on one class (seconds vs the full run):

```bash
docker run --rm -v "$PWD":/app -w /app --entrypoint composer composer-pcov:local \
  exec -- infection --threads=max --filter=ClassName.php --no-progress 2>&1 \
  | grep -vF SplObjectStorage | grep -vF Deprecated: | sed -n '/Generate mutants/,$p'
```

For each survivor read the diff, then write a test whose assertion differs
between original and mutant. Re-run the filter until only equivalents remain.

## 3. Killing-test patterns (what actually kills mutants)

| Survivor kind | How to kill |
|---|---|
| SQL string concat (`Concat`, `ConcatOperandRemoval`) | `Assert::same` the **exact** built SQL, not `Assert::string($s)->contains(...)` |
| `Identifier::assert` removal (`MethodCallRemoval`) | an `Expect::exception(InvalidArgumentException::class)` test per branch (each method, each qualified/unqualified path) |
| `substr`/index math on `db.table` | call with a db-qualified name, assert exact `db`/`tbl` params |
| `Ternary`/branch (`isEmpty() ? a : b`) | a test that forces the other branch (e.g. `count()` *with* a filter) |
| default param value (`DecrementInteger` on `= 20`) | call without the arg, assert the default appears |
| `< 0` → `<= 0` (`LessThan`) | boundary test: value `0` must NOT throw |
| `array_map($mapper, …)` unwrap | use a **non-identity** mapper, assert transformed output |
| `clone $this` removal | assert the original object is unchanged + `Assert::notSame` |
| `(string)`/`Stringable` cast | pass a `Stringable` value, assert the stringified param |
| `clone $date` in tz convert | assert the input `DateTime` timezone is unmutated |
| regex anchors (`^`/`$`) in a type check | feed an edge "type" with leading/trailing junk so the anchor matters |
| logger calls (`MethodCallRemoval`, `ArrayItemRemoval`) | a `createMock(LoggerInterface)` with `expects(...)->with(...)` |
| `insert`/`executeQuery` calls | capture call args via `willReturnCallback`, `Assert::same` the whole structure |

`failOnWarning=true` / `failOnRisky=true` gotchas:
- To make `file_get_contents` return `false`, use a **broken symlink** (a
  directory returns `""` on Linux, not `false`). Wrap the call in
  `set_error_handler(fn() => true)` / `restore_error_handler()` to swallow the
  warning so the test doesn't fail on it.
- Keep psalm green: avoid deep `mixed` array access in assertions —
  `Assert::same` the whole captured array; cast `mixed` before concatenation.

## 4. Classify the irreducible survivors

Some mutants are **unkillable by nature** — don't chase them. Common ones:

- `max(0, x ?? 0)` → `?? -1` (clamp makes it equivalent)
- redundant `(int)`/`(string)`/`(bool)(int)` casts on already-typed JSON values;
  `(int)` on a `%d` sprintf arg
- `sort()` after `glob()` (glob already sorts); `glob() === false` (unreachable —
  glob returns `[]` for a missing dir)
- wall-clock polling: `microtime`/`usleep` loops (`Plus`, `>=`→`>`, `usleep ±1`)
- `match (true)` constant subject — PCOV reports the `TrueValue` mutant as
  "not covered"
- a `match`/default arm whose output equals another arm (e.g. `All` ⇒ `['', []]`
  == default)
- `array_merge($acc, $x)` where `$acc` is provably `[]` at that point

## 5. Decide: honest minMsi vs documented ignores

Two legitimate endings — **ask the user which they prefer**:

**A. Lower `minMsi` to the honest ceiling (no ignores).** Kill everything
killable, then set `minMsi` to the floor integer just under the achieved MSI
(leave margin for timing flakiness on polling mutants). Cleanest; nothing hidden.

**B. Keep `minMsi: 100` with documented ignores.** Add ignores in
`infection.json5` with a comment justifying each. Mechanics (infection 0.29):
- per-mutator `ignore` / `global-ignore` take `Class::method` (and
  `Class::method::<line>` for a specific line) via `fnmatch`. These **prevent the
  mutant from being generated** (total count drops). This is the reliable lever.
- `ignoreSourceCodeByRegex` filters at test time by matching the **diff** with
  `/^-\s*<regex>$/mu` — the regex must match the WHOLE removed source line, not a
  substring. Easy to get silently wrong; prefer `Class::method::<line>`.
- A method-level ignore also drops adjacent **killable** mutants of that mutator
  in the same method — scope as narrowly as possible.

Whichever ending: re-run the full `composer mutation` and a full `composer build`
and paste both exit codes.

## 6. Record the run

Update `infection.json5` (`minMsi` and/or documented ignores). Tests live under
`tests/` (export-ignored — no version bump warranted; see **publish-php-package**
"Do not tag if the dist did not change").

## Golden rules

1. Never claim a target MSI without a fresh `composer mutation` run — paste the
   number and exit code.
2. No `@psalm-suppress`. New tests must keep `composer build` green.
3. Don't fake-kill: a test that doesn't assert the mutated behavior leaves the
   mutant "escaped". Assert the exact value.
4. Ignoring a mutant is a claim it's equivalent/untestable — justify each in a
   comment. When in doubt, prefer lowering `minMsi` over hiding a real gap.
