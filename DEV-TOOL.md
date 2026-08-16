# DEV-TOOL.md — using bin/dev

`bin/dev` runs batch operations across the workspace packages. Invoke it from
the monorepo root: `bin/dev <command> [arguments] [selector] [options]`.
Help: `bin/dev help`.

## Package selector

The last positional argument of almost every command. Forms combine with commas.

| Form | Example | What it selects |
|---|---|---|
| Empty | `bin/dev git:status` | Every package in the workspace |
| List | `bin/dev build yii3-outbox,yii3-outbox-db` | The named packages |
| Glob | `bin/dev build 'yii3-outbox*'` | By pattern (**quote it**, or the shell expands it first) |
| Alias | `bin/dev build @outbox` | A package family; full list via `bin/dev aliases` |
| Combo | `bin/dev list '@outbox,yii3-webhooks*'` | Union, deduplicated |

A selector that matches nothing is an error, not a silent no-op. `templates/`
and directories without a `composer.json` are never selected.

## Inspecting and running commands

```bash
bin/dev list @ab                  # what the selector resolves to (check before mutating)
bin/dev aliases                   # family aliases plus package counts

bin/dev exec "composer validate" @outbox   # shell command inside each package
bin/dev build @outbox             # = exec "make build"
bin/dev test yii3-seo             # = exec "make test"
bin/dev cs-fix 'yii3-mcp*'        # = exec "make cs-fix"
bin/dev psalm                     # = exec "make psalm" across EVERY package
```

- Runs **in parallel** (`-j$(nproc)`); `-j4` or `--serial` throttle it.
- Output is buffered and printed as one block per package (`=== pkg ===`), in
  launch order.
- The overall exit code is non-zero if any package failed; a `FAILED (n/m)`
  summary is printed at the end.

## Batch git

```bash
bin/dev git:status                # package + branch + *dirty; exit 1 if anything is dirty
bin/dev git:branch @ab            # branches of each repository, * marks the current one

bin/dev git:checkout master @ab              # switch a whole family
bin/dev git:checkout -b feat/x @ab           # create the branch in every repository
bin/dev git:commit "Fix Y." @ab              # add -A + commit; clean packages are skipped
bin/dev git:push @ab                         # push -u origin HEAD (works for a new branch)
bin/dev git:pull                             # pull --ff-only everywhere
```

Rules:

- **`--dry-run` exists for checkout/commit/push** — it prints the plan and
  changes nothing. Make it a habit: once with `--dry-run`, then without.
- `git:checkout` on a dirty tree **aborts before switching anything** and names
  the offenders. `--stash` works around it (stash push → checkout → stash pop).
- Hooks are never suppressed.
- Remember that `master` is protected on published packages — `git:push` of a
  branch is fine, a direct push to master is rejected by GitHub.

## Editing a whole family (the standard flow)

```bash
bin/dev git:status @ab                            # 1. is the starting state clean?
bin/dev git:checkout -b feat/new-thing @ab        # 2. branch everywhere
# ... edit the packages ...
bin/dev build @ab                                 # 3. green build everywhere
bin/dev changelog:add "Add new thing." --type=added @ab   # 4. CHANGELOG everywhere
bin/dev git:commit "Add new thing" @ab --dry-run  # 5. the plan
bin/dev git:commit "Add new thing" @ab            # 6. commit
bin/dev git:push @ab                              # 7. branches on GitHub → PRs
```

## changelog:add

```bash
bin/dev changelog:add "Fix race in flush()." --type=fixed @outbox
```

- Writes into `## Unreleased` → `### <Type>` (keep-a-changelog); it creates the
  sections itself.
- `--type=` `added|changed|fixed|removed|breaking`; defaults to `changed`.
- Idempotent: an identical entry is not added twice.
- At release time you rename `## Unreleased` to `## X.Y.Z — date` as usual.

## replicate (templates → packages)

```bash
bin/dev replicate:check           # drift of packages from templates/ per the manifest; exit 1 on drift
bin/dev replicate:files --dry-run # what would be overwritten
bin/dev replicate:files           # apply (copies only what differs)
bin/dev replicate:copy-file templates/foo.md docs/foo.md @ab   # ad-hoc file into packages
```

The manifest is `replicate/manifest.bash`. It holds the files that must stay
byte-identical in every package: `.editorconfig`, the three
`.github/ISSUE_TEMPLATE/` files and `.github/workflows/zizmor.yml`. A
2026-07-11 audit found that the remaining template files differ between
packages **deliberately** (rector `withSkip`, per-package Makefile/testo
suites, and so on) — the reasons are listed in the manifest's comment. Before
adding a file to the manifest, make sure of two things: it is meant to be
identical in every package, AND the template is the canonical version.

## Options (summary)

| Option | Where it applies | Meaning |
|---|---|---|
| `--dry-run` | git:checkout/commit/push, replicate:files/copy-file, changelog:add | Plan without mutating |
| `--stash` | git:checkout | Stash dirty trees around the switch |
| `--type=T` | changelog:add | Entry type (default: changed) |
| `--serial` | exec, build/test/cs-fix/psalm | Sequential instead of parallel |
| `-jN` | exec, build/test/cs-fix/psalm | Cap the parallelism |

## What bin/dev deliberately does NOT do

| Not supported | Do this instead |
|---|---|
| `release:make` (tag/release) | The flow in `AGENTS.md` "Process: publishing" — by hand or via an agent; the cost of a mistaken re-tag is too high |
| `install`/`link` (symlinks into vendor) | The path-repo recipe: repository `type: path, url: ../<pkg>` plus `"minimum-stability": "dev"` in the consumer |
| Batch releases | A release is a deliberate single-package step |
| `replicate:composer` (deep merge) | Deferred until it actually hurts; edit sections with `bin/dev exec` + jq/sed |

## Self-testing

After any change to `bin/dev` or `bin/dev-lib/*`:

```bash
bin/dev-self-test    # must report N passed, 0 failed
```

The tests run against a fixture workspace in /tmp — real packages are never
touched.
