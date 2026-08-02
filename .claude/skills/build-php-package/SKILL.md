---
name: build-php-package
description: Use when building, testing, or fixing a PHP package in this monorepo. Triggers on "build package", "composer build", "run tests", "fix psalm", "fix cs", "собери пакет". Knows Docker commands, understands build output, guides error fixing.
---

# Build PHP Package

Build, test, and fix PHP packages in this monorepo. All commands run via Docker (`composer:2` image) — no PHP on host.

## Context

Read the package's own `AGENTS.md` first — it has package-specific invariants and gotchas.

## Commands

Prefer `bin/build-digest <package-dir> <script>` (run from the monorepo root)
over the raw `docker run ... composer <script>` form below. A single
`composer build`/`test`/`psalm` run routinely produces hundreds of lines;
`build-digest` captures the full output to
`<package-dir>/build/digest-<script>.log` and prints one `PASS`/`FAIL` line
(plus the log's last 30 lines on failure) instead of dumping it all inline.
Open the log directly when you need the full detail.

### Full gate

```bash
bin/build-digest <package-dir> build
```

This runs: `validate → normalize → require-checker → cs → psalm → test`

### Individual tools

```bash
bin/build-digest <package-dir> cs:fix
bin/build-digest <package-dir> psalm
bin/build-digest <package-dir> test
bin/build-digest <package-dir> rector:fix
```

### Raw Docker form (equivalent, no digest — use for a one-off command not
worth a log file, or when you want the output inline immediately)

Run from the package root directory (e.g. `<monorepo-root>/clickhouse-toolkit`):

```bash
docker run --rm -v "$PWD":/app -w /app composer:2 composer build
docker run --rm -v "$PWD":/app -w /app composer:2 composer cs:fix
docker run --rm -v "$PWD":/app -w /app composer:2 composer psalm
docker run --rm -v "$PWD":/app -w /app composer:2 composer test
docker run --rm -v "$PWD":/app -w /app composer:2 composer rector:fix
```

### After changing composer.json

```bash
docker run --rm -v "$PWD":/app -w /app composer:2 sh -c \
  'git config --global --add safe.directory /app; composer update -q; composer normalize'
```

### Coverage + mutations (needs a coverage driver — NOT in `composer:2`)

`composer build` does **not** run mutation testing — `composer mutation` (the
`minMsi` gate) runs only in the CI "Coverage & Mutation" job. A green
`composer build` can still hide a failing mutation gate.

The stock `composer:2` image has **neither pcov nor `ext-intl`**, so
`composer mutation` and `composer test:coverage` fail there. Build a reusable
`composer-pcov:local` image once:

```bash
cid=$(docker create --entrypoint sh composer:2 -c '
  apk add --no-cache $PHPIZE_DEPS icu-dev >/dev/null 2>&1
  docker-php-ext-install intl >/dev/null 2>&1
  pecl install pcov >/dev/null 2>&1
  docker-php-ext-enable pcov')
docker start -a "$cid" >/dev/null 2>&1; docker commit "$cid" composer-pcov:local >/dev/null; docker rm "$cid" >/dev/null
```

Then run coverage / mutations against that image:

```bash
docker run --rm -v "$PWD":/app -w /app --entrypoint composer composer-pcov:local test:coverage
docker run --rm -v "$PWD":/app -w /app --entrypoint composer composer-pcov:local mutation
```

Infection's text log goes to `php://stderr`; redirect it to a host path you own
(e.g. `2>/tmp/mut.log`), not into the root-owned `build/`. To iterate fast on one
class, filter it:

```bash
docker run --rm -v "$PWD":/app -w /app --entrypoint composer composer-pcov:local \
  exec -- infection --threads=max --filter=ClassName.php --no-progress
```

To actually raise MSI (kill survivors, classify equivalent mutants, set the
`minMsi` gate honestly), use the **mutation-php-package** skill.

## Error fixing guide

### composer normalize fails

Run: `docker run --rm -v "$PWD":/app -w /app composer:2 composer normalize`

### cs (php-cs-fixer) fails

Run: `docker run --rm -v "$PWD":/app -w /app composer:2 composer cs:fix`

Then re-run `cs` to verify.

### psalm fails

1. Never add `@psalm-suppress` — fix the root cause.
2. Common fixes:
   - Add explicit return/param types
   - Narrow types with assertions or checks
   - Add `@template`, `@param`, `@return` annotations for generics
   - Restructure code to eliminate mixed types
3. If a global suppression is truly unavoidable (e.g. third-party API returns broad types), add it to `psalm.xml` `<issueHandlers>`, NOT as inline `@psalm-suppress`.

### require-checker fails

Missing dependency in `composer.json`. The tool reports which symbol is used but not declared. Add it to `require` or `require-dev`.

### testo fails

1. Read the test output — it shows which test and assertion failed.
2. Fix the source code or test, not the assertion (unless the test was wrong).
3. For integration tests: check if env vars are set (`CLICKHOUSE_HOST`, etc.).

### rector fails

Run: `docker run --rm -v "$PWD":/app -w /app composer:2 composer rector:fix`

## Integration tests

### SQLite (specification pattern)

No external service needed — uses in-memory SQLite via `ext-pdo_sqlite` + `yiisoft/db-sqlite`.
Covered by `composer build` automatically.

### ClickHouse (clickhouse-toolkit)

Requires a running ClickHouse server. Skip condition: `CLICKHOUSE_HOST` env var not set.

```bash
docker rm -f ch-test 2>/dev/null
docker run -d --name ch-test -p 8123:8123 -e CLICKHOUSE_PASSWORD=ch_test \
  clickhouse/clickhouse-server:24.8
for i in $(seq 1 40); do curl -fs -H 'X-ClickHouse-User: default' \
  -H 'X-ClickHouse-Key: ch_test' --data-binary 'SELECT 1' \
  http://127.0.0.1:8123/ | grep -q '^1$' && break; sleep 1; done
docker run --rm --network host -v "$PWD":/app -w /app \
  -e CLICKHOUSE_HOST=127.0.0.1 -e CLICKHOUSE_PASSWORD=ch_test \
  composer:2 vendor/bin/testo --suite=Integration
docker rm -f ch-test
```

## Golden rules

1. Never claim "done" without a fresh green `composer build`. Report the
   `build-digest` PASS/FAIL summary line (or paste the raw output if you ran
   the Docker form directly) — a claim with no run behind it doesn't count.
2. No suppressions — fix root cause.
3. `composer.lock` is gitignored — don't commit it.
4. `git ... dubious ownership` lines in output are harmless noise.
5. Building/auditing many packages at once (`--all`, a whole `@family`)
   produces output that multiplies by package count — delegate to a subagent
   (Agent tool / Workflow) that reports back a compact per-package
   pass/fail table, rather than running it inline and reading every
   package's full log yourself.
