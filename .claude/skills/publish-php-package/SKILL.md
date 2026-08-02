---
name: publish-php-package
description: Use when publishing or releasing a rasuvaeff/* Composer package. Triggers on "publish package", "release", "create tag", "publish to packagist", "опубликуй пакет". Automates: GitHub repo creation, Packagist registration, SemVer tagging, CHANGELOG update.
---

# Publish PHP Package

Publish a finished `rasuvaeff/*` package to GitHub, Packagist, and create a release tag.

## Pre-flight checklist

Before publishing, verify ALL of these:

```bash
# From the package directory
docker run --rm -v "$PWD":/app -w /app composer:2 composer build
```

- [ ] `composer build` passes green
- [ ] `composer validate --strict` passes
- [ ] No `@psalm-suppress` in source (grep for it)
- [ ] All public classes have `@api`
- [ ] All test classes have `#[Covers]`
- [ ] `README.md` is up to date with current API
- [ ] `CHANGELOG.md` has entry for the version being released
- [ ] `composer.json` has `homepage` and `support` URLs
- [ ] `.gitattributes` marks dev files as `export-ignore`
- [ ] No `App\*` imports in src/ or tests/ (grep `rg '^use App\\' src tests`)

If any check fails — **stop and fix before publishing**.

## Do not tag if the dist did not change

`.gitattributes` marks `tests/`, `infection.json5`, `testo.php`,
`.github/`, `examples/` and friends as `export-ignore` — they are **not** in the
Composer dist consumers download. If a change touched only export-ignored files
(new tests, raised `minMsi`, CI) while `src/` is untouched, a new tag would ship
a **byte-identical** package. Don't tag: merge to `master`, wait for green CI,
done.

Quick check before tagging (subsequent releases):

```bash
git diff --stat "$(git describe --tags --abbrev=0)"..HEAD -- src
# empty output => src unchanged => no tag needed
```

## Step 1: Update CHANGELOG.md

Set the release date:

```markdown
## X.Y.Z — YYYY-MM-DD

- Description of change.
```

SemVer rules:
- **Major** (X.0.0): breaking API changes
- **Minor** (0.Y.0): new features, backwards-compatible
- **Patch** (0.0.Z): bug fixes, backwards-compatible

## Step 2: Commit the release (do NOT tag yet)

```bash
cd <package-directory>
git add CHANGELOG.md
git commit -m "Release X.Y.Z"
```

**Do not tag and do not protect `master` yet.** On an initial publish the tag
and branch protection go on **after** the first pipeline is green (Step 4).
Tagging or locking `master` before the first green run is what forces the
delete-tag + recovery-PR dance when the very first CI run is red (e.g. a PHP
version the local `composer:2` image never exercised).

## Step 3: Create GitHub repository and push master

### Option A: via `gh` CLI

```bash
gh repo create rasuvaeff/<package-name> \
  --public --source=. --remote=origin \
  --description "<description from composer.json>" \
  --push
```

### Option B: manually

1. Create empty public repo at https://github.com/new (no README/License/gitignore)
2. Push:

```bash
git remote add origin git@github.com:rasuvaeff/<package-name>.git
git push -u origin master
```

**Wait for GitHub Actions to go green** (check the **Actions** tab / `gh run watch`).
Because `master` is not protected yet, a red first run is fixed **directly on
master** — edit, commit, push, re-check — no PR needed. Only proceed once the
whole pipeline is green.

## Step 4: Tag the release (only after the pipeline is green)

With a green master:

```bash
git tag -a vX.Y.Z -m "X.Y.Z"
git merge-base --is-ancestor vX.Y.Z origin/master && echo OK   # tag is on the green commit
git push origin vX.Y.Z
```

## Step 5: Apply master branch protection

Lock down `master` — **after** the pipeline is green and the tag is pushed, so a
red first run could still be fixed directly on master above:

```bash
gh api -X PUT "repos/rasuvaeff/<package-name>/branches/master/protection" \
  --input "${MONOREPO_ROOT}/templates/branch-protection.json"
```

## Step 6: Verify clean clone

```bash
bin/verify-clean-clone <package-name>
```

Clones fresh into a throwaway temp dir and runs `composer install` + `composer
build` against it exactly as a first-time consumer would — no local package
state (`vendor/`, caches) can leak in and hide a broken dist. Use `--https` if
no SSH key is configured in the current environment.

## Step 7: Register on Packagist

1. Log in at https://packagist.org (via GitHub)
2. **Submit** → paste `https://github.com/rasuvaeff/<package-name>` → Submit
3. Set up auto-update: install the Packagist GitHub App or add webhook

## Step 8: Verify install

```bash
docker run --rm -v "$PWD":/tmp/app -w /tmp/app composer:2 \
  composer require rasuvaeff/<package-name> --dry-run
```

`--dry-run` confirms Packagist resolved the package and its constraints
without touching the current working directory's `composer.json`/`vendor/`.

## Post-publish

- Badges in README will start working (they reference the GitHub repo)
- Set up Codecov: add `CODECOV_TOKEN` secret in GitHub repo settings → Secrets → Actions
- Update the "Existing packages" section in `<monorepo-root>/AGENTS.md` if new package

## Releasing subsequent versions

`master` is protected (required PR + status checks) — direct push is rejected.
The release commit goes through a PR, the tag is placed **on the merged commit**.

> **Every tag requires a CHANGELOG entry.** No exceptions — internal changes
> (test migrations, CI bumps, dev-dependency updates) still need a record.
> Add the entry to the PR branch before merging. If the entry is missing,
> update it on the feature branch and wait for CI to re-pass. Never tag a
> commit without a matching `## X.Y.Z — YYYY-MM-DD` block in CHANGELOG.

0. **Check the dist changed** (see "Do not tag if the dist did not change"
   above) — `git diff --stat <last-tag>..HEAD -- src`. Empty => skip the tag.
1. Update code + tests + README (feature-branch → PR → CI → merge).
2. Update CHANGELOG with new version entry (on the release branch).
3. `git commit -m "Release X.Y.Z"` on the release branch.
4. PR → wait for green CI → merge (squash/rebase — any).
5. `git checkout master && git pull --ff-only`.
6. `git tag -a vX.Y.Z -m "X.Y.Z"` **on the post-merge HEAD**.
7. Verify: `git merge-base --is-ancestor vX.Y.Z origin/master && echo OK`.
8. `git push origin vX.Y.Z` — **once, never move it**.
9. Packagist auto-detects the new tag within ~1 minute.

> **Re-tag is forbidden.** Never delete and recreate a tag after pushing it to
> the VCS. Packagist blocks re-tagged versions permanently
> (`Upstream re-tag blocked`); the only way out is a new patch version. Tag
> **after** merge, not before — squash/rebase create a new SHA.
