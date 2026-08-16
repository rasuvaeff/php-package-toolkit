---
name: contribute-yiisoft
description: Use when filing an upstream fix/PR to a yiisoft/* package (found while building or using a dependency in a rasuvaeff package). Triggers on "upstream PR", "fix yiisoft", "contribute to yiisoft", "апстрим", "контрибьют в yiisoft", "PR в yiisoft".
---

# Contribute a fix upstream to yiisoft/*

Draft workflow, based on `yiisoft/db-migration#350` (first upstream PR from
this account, filed 2026-08-02, merged 2026-08-03). Not yet battle-tested on
a second contribution — revise once more data points exist.

## 0. Is this the right move?

Only file upstream when the bug is genuinely in the yiisoft package, not a
misuse on our side (see `docs/evolved-rules.md` for prior misdiagnoses).
Reproduce it minimally first — a failing test in the *upstream* package's own
test suite, not just symptom in a rasuvaeff consumer.

## 1. Prerequisites

Read before writing code — yiisoft has house conventions that diverge from
`AGENTS.md` in this monorepo (PHPUnit not Testo, different commit style):

- [Yii goal and values](https://github.com/yiisoft/docs/blob/master/001-yii-values.md)
- [Namespaces](https://github.com/yiisoft/docs/blob/master/004-namespaces.md)
- [Git commit messages](https://github.com/yiisoft/docs/blob/master/006-git-commit-messages.md)
- [Exceptions](https://github.com/yiisoft/docs/blob/master/007-exceptions.md)
- [Interfaces](https://github.com/yiisoft/docs/blob/master/008-interfaces.md)
- Each repo's own `.github/CONTRIBUTING.md` — check for package-specific notes.

## 2. Fork and branch

```bash
gh repo fork yiisoft/<package> --clone=false
git clone git@github.com:rasuvaeff/<package>.git /tmp/<package>
cd /tmp/<package>
git checkout -b fix/<short-description>
```

Branch naming: `fix/...` / `feat/...`, matching this monorepo's own
convention — yiisoft doesn't enforce one.

## 3. Fix + regression test

- Add a **regression test in the upstream package's own suite** (usually
  PHPUnit, `tests/`), not just in a rasuvaeff consumer.
- Don't assume Linux-only behavior. yiisoft CI runs Windows too — path
  separators are a common trap: helper methods like `normalizePath()` often
  force `/`, but building test expectations from PHP's own `dirname()` /
  `DIRECTORY_SEPARATOR` will differ on Windows. Normalize both sides in
  assertions, not just one.

## 4. Expect the full CI matrix

yiisoft packages run a wide gate — check `.github/workflows/` in the target
repo for the actual list (varies by package: DB packages add per-driver jobs
like `mysql.yml`/`pgsql.yml`/`mssql.yml`/`oracle.yml`/`mariadb.yml`). Typical
common set:

| Workflow | Checks |
|---|---|
| `build.yml` | PHPUnit across a PHP matrix (often 8.1-8.5) × Linux/Windows |
| `static.yml` | Psalm |
| `rector-cs.yml` | Rector + CS |
| `bc.yml` | Backward-compatibility (roave) |
| `composer-require-checker.yml` | Declared vs used dependencies |
| `mutation.yml` | Infection |
| `zizmor.yml` | Workflow security lint |

All must be green before requesting review — don't ping for review on a red
matrix.

## 5. PR

- Add a `CHANGELOG.md` entry **right after opening the PR**, not as an
  afterthought once a reviewer asks for it (happened on #350 — fixed only
  after vjik prompted). Push it as a follow-up commit on the same branch the
  moment GitHub assigns the PR number: under the top `## X.Y.Z under
  development` section (create it if the last released version heads the
  file), following the existing line format:
  `- <Type> #<PR-number>: <description> (@<your-github-handle>).`
  Type is one of `New`/`Enh`/`Bug` (see existing entries for the package).
- Reference an issue if one exists (`Fixes #N`); if none, describe repro +
  root cause in the PR body directly.
- Follow the Git commit messages doc (§1) for the PR title — yiisoft
  maintainers read commit history, not just PR titles, as changelog input.
- If you don't have a specific package in mind next time: check the
  [roadmap](https://github.com/yiisoft/docs/blob/master/003-roadmap.md),
  browse issues on the target repo, or ask `@samdark` per the org's own
  CONTRIBUTING.md.

## 6. After merge — don't assume released

**Merged to `master` ≠ tagged ≠ on Packagist.** Before bumping the
`yiisoft/<package>` constraint in any rasuvaeff package or removing a
workaround/warning tied to the bug:

```bash
gh api repos/yiisoft/<package>/tags --jq '.[0].name'
gh api repos/yiisoft/<package>/commits?sha=master --jq '.[0].sha[0:7]'
```

Confirm the merge commit is reachable from the latest tag, not just from
`master`'s tip.

## Golden rules

1. Regression test lives in the *upstream* repo's suite — a rasuvaeff-side
   test alone doesn't protect the fix from regressing there.
2. Full upstream CI matrix green before requesting review, including any
   OS/driver-specific jobs.
3. Never claim "merged and available" without checking for a tag past the
   merge commit — composer resolves tags, not `master`.
4. Update this skill after the *next* contribution — one data point isn't
   enough to know what's generic vs specific to `db-migration`.
