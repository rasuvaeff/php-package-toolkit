# php-package-toolkit

The toolchain behind the [public `rasuvaeff/*` PHP packages](https://packagist.org/packages/rasuvaeff/)
maintained by one person in a single workspace: the templates every package is
cut from, the batch tooling that operates on all of them at once, the machine
audit that keeps them uniform, and the written rulebook — including a catalogue
of every gotcha that cost real time.

## Read this first

This is a **showcase, not a product.**

- There is no installer and no configuration layer. `bin/dev` and friends assume
  a specific layout: a workspace root whose direct children are package
  directories, each its own git repository with a `composer.json` and a
  `Makefile`.
- Nothing here is on Packagist. There is no versioning, no backwards-compatibility
  promise, and no support commitment.
- It is published because the interesting part is not the code — it is the
  answer to "how does one person keep 55 packages consistent, statically clean,
  mutation-tested and release-safe?" That answer is a process, and this is the
  process, verbatim.
- **It is a snapshot, taken 2026-08-02, not a mirror.** The working copy lives in
  a private monorepo and keeps moving; this repository is not expected to track
  it. Read it as a record of how the packages were built, not as the current
  state of anyone's build system. The packages themselves are the living
  artefacts.

Copy anything you find useful. Expect to adapt it.

## What's inside

| Path | What it is |
|---|---|
| [`AGENTS.md`](AGENTS.md) | The rulebook. File set, code style, test conventions, CI requirements, security rules, naming, and the four end-to-end processes (create / build / review / publish a package) |
| [`docs/evolved-rules.md`](docs/evolved-rules.md) | `ER-001` … `ER-046` — a numbered catalogue of concrete engineering gotchas found in production work: CI traps, static-analysis conflicts, mutation-testing quirks, DI wiring pitfalls, release-process incidents. Each entry records what broke, why, and the rule that came out of it |
| [`DEV-TOOL.md`](DEV-TOOL.md) | How to drive `bin/dev` |
| [`templates/`](templates/) | The skeleton a new package is cut from: `composer.json`, psalm/rector/infection/php-cs-fixer configs, `Makefile`, hardened GitHub Actions workflows, branch-protection payload, doc stubs |
| [`bin/dev`](bin/dev) + [`bin/dev-lib/`](bin/dev-lib/) | Batch operations across packages — parallel `exec`/`build`/`test`/`psalm`, batch git with `--dry-run`, batch CHANGELOG entries, template replication |
| [`bin/package-audit`](bin/package-audit) | Deterministic per-package audit: required files, `@api`/`@internal` on every type, `#[Covers]` on every test class, no psalm suppressions, docs mention every public type, examples actually run |
| [`bin/build-digest`](bin/build-digest) | Runs a composer script in Docker and prints one `PASS`/`FAIL` line instead of several hundred — the difference between a usable and an unusable agent session |
| [`bin/verify-clean-clone`](bin/verify-clean-clone) | Clones a published package into a temp dir and builds it there, so "works on my machine" is never the claim |
| [`bin/dev-self-test`](bin/dev-self-test) | A self-test suite for the batch tooling itself, run against a fixture workspace in `/tmp` |
| [`.claude/`](.claude/) | The agent layer: five skills (create / build / review / publish / raise mutation score), a package-builder subagent, and two `PreToolUse` hooks — a bash-command guard and a pre-commit audit |
| [`replicate/manifest.bash`](replicate/manifest.bash) | The short list of files that are meant to be byte-identical across packages. It is short on purpose — most template files diverge deliberately |

## The gates a package has to pass

`make build` is one command and it is the gate. It fails on any of:

| Check | Tool | Setting |
|---|---|---|
| Manifest validity | `composer validate` + `ergebnis/composer-normalize` | strict |
| Undeclared dependencies | `maglnet/composer-require-checker` | any import not in `composer.json` fails |
| Code style | `friendsofphp/php-cs-fixer` | dry-run, diff on failure |
| Static analysis | `vimeo/psalm` | **`errorLevel="1"`**, no baseline, `@psalm-suppress` banned outright |
| Tests | [`testo/testo`](https://php-testo.github.io) | every public class needs a test class carrying `#[Covers]` |

Outside the build gate, because they need a coverage driver or a previous tag:

| Check | Tool | Setting |
|---|---|---|
| Mutation testing | `infection/infection` via `testo/bridge-infection` | `minMsi` starts at 85 and is raised as a package matures |
| Backwards compatibility | `roave/backward-compatibility-check` | required status check; a major release only passes when the CHANGELOG declares the major |
| Automated refactoring | `rector/rector` | dry-run in `release-check` |

CI is hardened rather than convenient: every `uses:` is pinned to a 40-character
commit SHA with a `# vN` trailing comment, workflows declare
`permissions: { contents: read }`, every checkout sets `persist-credentials: false`,
and `zizmor --persona=auditor` must report no `unpinned-uses`,
`excessive-permissions` or `artipacked` findings. Updates come through
Dependabot, which bumps SHA pins in place.

Published packages run with protected `master`: pull request required, status
checks required, no direct pushes. The exact payload is
[`templates/branch-protection.json`](templates/branch-protection.json).

## How it is actually used

```bash
# what will a selector touch, before touching it
bin/dev list @outbox

# green build across a whole package family, in parallel
bin/dev build @outbox

# one package, hundreds of lines of output reduced to one
bin/build-digest yii3-outbox build

# conventions check that does not need a human
bin/package-audit yii3-outbox

# coordinated change across a family
bin/dev git:checkout -b feat/thing @outbox
bin/dev changelog:add "Add thing." --type=added @outbox
bin/dev git:commit "Add thing" @outbox --dry-run
bin/dev git:push @outbox
```

The `Makefile` wraps every command in the `composer:2` Docker image, so no host
PHP or Composer installation is required.

Releases are deliberately **not** batched. Tagging is a single-package,
single-shot step, because Packagist blocks re-tagged versions permanently; the
full sequence, and the reasoning, are in `AGENTS.md`.

## Why `docs/evolved-rules.md` is the interesting file

The rulebook says what to do. The evolved rules say what happened when it went
wrong. A sample of what is in there:

- A `$` anchor in a validation whitelist matches before a trailing newline, so
  `"…\n"` passes a regex meant to reject it (`ER-001`).
- `#[Covers]`-driven mutant mapping means a test that exercises another class's
  code kills none of its mutants — the coverage number lies in a specific,
  predictable way (`ER-003`).
- `[BC] SKIPPED` from the backwards-compatibility checker means the symbol was
  never actually compared — and it fails in both directions: sometimes it passes
  silently while checking nothing (`ER-016`), and on an enum-case or `new`
  expression used as the default of a promoted readonly property it is counted
  as a breaking change, turning a required status check permanently red for
  every future pull request (`ER-046`).
- `yiisoft/db-migration` matches PSR-4 namespaces by string prefix, lands in the
  wrong package, and returns "0 migrations" without an error (`ER-044`).

Every entry carries its source and a status, and superseded entries stay in the
file rather than being deleted.

## License

BSD-3-Clause. See [LICENSE.md](LICENSE.md).
