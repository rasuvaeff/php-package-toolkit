# Evolved Rules

A living list of gotchas — concrete technical pitfalls found in real work on
the packages of this monorepo (reviews, debugging, incidents, CI). This is a
**supplement** to `/AGENTS.md`, not a replacement: `AGENTS.md` holds the
principles and their rationale, this file holds the accumulated experience
that is too specific or too bulky to live in the root rulebook.

Entry format: `ER-NNN`, a title, the source (which package or session
surfaced it), the rule itself (self-contained — a future agent must be able
to act on it with no other context), and a status (`active` / `superseded` /
`obsolete`).

New finding → a new `ER-NNN` at the end of the matching section (or a new
one). Do not duplicate verbatim what `AGENTS.md` already says — update it
there instead.

---

## Security

### ER-001 — PCRE `$` matches before a trailing newline — anchor with `\z`

**Source:** `yii3-ab-testing-web` 1.1.0 incident (moved out of the root `AGENTS.md` § Security)
**Rule:** `preg_match('/^[0-9a-f]{32}$/', "aaaa…aaa\n")` returns 1 — in PCRE
`$` matches **both at the end of the subject and immediately before a
trailing `\n`**, so a whitelist shaped like `^…$` silently lets one trailing
`\n` through. Found live: an `ab_id` cookie ("32 hex plus a newline") passed
validation and became a subject id in logs and analytics. The fix is to
anchor untrusted-input validation with `\z` (or the equivalent `/D`
modifier), never `$`. `$` is only appropriate when matching a line inside
multiline text. Tests must carry a data-provider case with the value
`"value\n"` — otherwise the regression is invisible.
**Status:** active

### ER-002 — CRLF header injection cannot be tested through a real PSR-7 implementation

**Source:** `yii3-correlation-id`
**Rule:** A real PSR-7 implementation (Nyholm, for instance) rejects a header
value containing CRLF at `withHeader()` time — constructing a "malicious"
request object to test the defence against that injection is impossible, the
library refuses to build it. Instead of literal CRLF, test smuggling through
the legal variant (space/tab) inside a single header line.
**Status:** active

---

## Testo / Infection / property-testing

### ER-003 — Testo/infection: the mutant→test mapping is driven by `#[Covers]`, not by actual execution

**Source:** mutation-mapping investigation in testo, `media-converter` (M9)
**Rule:** `#[CoversNothing]` on an integration test yields **zero** mutants
for the classes that test actually exercises — this is not "lower priority",
it is a total absence of mutation checking. Reason: testo's coverage XML (and
infection's per-mutant test selection) is built from the `#[Covers]`
attribute, not from pcov tracing. The stronger form (found in
`media-converter`): a test in `FooTest` carrying `#[Covers(Foo::class)]` that
really executes `Bar.php` through composition still does not kill `Bar.php`
mutants — the test only counts towards the class(es) named in its own
`#[Covers(...)]` (the attribute is repeatable), regardless of what it
actually calls. Use `#[CoversNothing]` only for pure e2e smoke tests with no
claim on the mutation score; before trusting a package's mutation gate for a
class reachable only through an integration test, grep for `#[CoversNothing]`
and re-check the real coverage.
**Status:** active

### ER-004 — `#[Covers]` scoring does not save untested branches inside test code itself

**Source:** `media-converter` (M9)
**Rule:** The monorepo convention is that `psalm.xml` scans only `src/`, never
`tests/`. So a bug in test-helper code (calling a public readonly **property**
as a method, for example) is caught by neither static analysis nor
coverage/mutation until some real test run forces that exact branch to
execute. Rarely reachable paths in shared test fixtures and helpers
(error-handling branches, fixture-generation-failure paths) are effectively
unverified — treat helper-code branches "that should never fire" with the
same suspicion as untested production code, rather than assuming they are
safe.
**Status:** active

### ER-005 — PHP 8.3 rejects `new Foo()->bar()` without wrapping parentheses — lint the CI floor version, not just composer:2

**Source:** `circuit-breaker`, `media-converter`, `yii3-mcp` (independently in 3 packages)
**Rule:** `new Foo(...)->member` / `new Foo()->bar()` (member or method access
straight after `new` without wrapping parentheses) is PHP 8.4+ syntax; on 8.3
it is a parse error. The local `composer:2` image runs PHP 8.5, so
`composer build` stays green while the `PHP 8.3` and `Prefer-lowest` CI jobs
fail at the php-cs-fixer *lint* stage (exit 4) — the first real signal is
always CI, never the local run. Before pushing any new or touched package,
lint the tree on the floor version directly:
`docker run --rm -v "$PWD":/app -w /app php:8.3-cli sh -c 'for f in $(find src tests benchmarks examples -name "*.php"); do php -l "$f" >/dev/null || echo "FAIL $f"; done'`.
**Status:** active

### ER-006 — Rector's `RemoveUselessVarTagRector`/`RemoveNonExistingVarAnnotationRector` delete load-bearing `/** @var mixed */`

**Source:** `property-testing`, `rector-datetime-immutable`, `yii3-mcp` (and `yii3-mcp-rbac-bridge`)
**Rule:** A lone `/** @var mixed */` in front of an assignment from an
untyped boundary (`SessionInterface::get()`, `$inner->generate()`) suppresses
psalm level 1 `MixedAssignment` — it is not a decorative annotation. Rector's
dead-annotation cleanup rules delete it as "useless", which turns a fresh
`composer rector` red on files nobody touched (`composer.lock` is gitignored,
so a new rector release surfaces this on any clean install). The fix is
`rector.php` → `withSkip([RemoveUselessVarTagRector::class])` (plus
`RemoveNonExistingVarAnnotationRector::class` when it strips a `@var`
immediately before a `return` — that also breaks psalm-typed generic casts;
in that case bind the value to a variable instead of returning the cast
inline). This standard departure from the template `rector.php` is already in
bulkhead/property-testing/rector-datetime-immutable/yii3-mcp/yii3-mcp-rbac-bridge
— check for this pattern before adding a new `@var mixed`.
**Status:** active

### ER-007 — Never run a bare `composer rector:fix` without checking the skip list

**Source:** `bulkhead`, `property-testing`, `yii3-recaptcha` v2, the monitor-dashboard plan
**Rule:** A bare rector sweep can (a) delete the reflection-invoked
property-testing generator methods (`RemoveUnusedPrivateMethodRector`),
(b) strip a psalm-load-bearing `/** @var mixed */` (see ER-006), (c) drag
dozens of unrelated files with previously accumulated drift into the current
diff (rector is not part of the `build.yml` gate, only of `release-check`, so
drift on `master` piles up silently between touches). Before running: verify
that the `withSkip` list in `rector.php` is current; if `composer rector` is
red on files you did not touch, do **not** run `rector:fix` over the whole
tree — clean up only your own new or changed file and leave the existing red
as a separate, deliberate task.
**Status:** active

### ER-008 — Testo `#[Bench(...)]` requires a non-empty `callables:`

**Source:** CI-gotcha investigation across several packages, `media-converter`, `yii3-mcp` (telemetry-bridge), `rector-datetime-immutable` — independently in at least 5 packages
**Rule:** A bare `#[Bench]` with no `callables:` fails fatally at runtime with
`ArgumentCountError` — the attribute compares `current` against a comparison
callable, so even a single-subject benchmark needs at least a no-op baseline.
`composer build`/`composer test` do **not** run the Benchmarks suite (`test`
is `--suite=Unit` only), so a broken bench lands in a commit green and only
surfaces on `composer bench` — run it before committing any new benchmark.
A "risky" verdict in bench results is RStDev-variation noise, not a failure.
**Status:** active

### ER-009 — Testo `Assert::fail()` is not an immediate PHPUnit-style failure

**Source:** `rector-named-literals`
**Rule:** `Assert::fail()` registers the expectation "this test must fail" and
throws — under the property-testing runner, if that expectation is not met
independently, the test is reported as **Risky with PASSED**, not Failed. In
property tests, check the boolean condition directly instead of signalling a
bad case through `Assert::fail()`.
**Status:** active

### ER-010 — A committed-empty test/benchmark directory passes locally and breaks CI from a fresh clone

**Source:** CI-gotcha investigation across several packages, `yii3-tenancy`, `rector-named-literals` — independently at least twice
**Rule:** Git does not track empty directories. If `testo.php` declares a
`SuiteConfig`/`FinderConfig` pointing at a directory (`tests/Integration`,
`benchmarks`) with not a single committed file in it, a fresh CI checkout
fails with `File or directory not found` — and since testo eagerly validates
the finder of **every** suite while loading the config, this breaks the
**entire** `composer build`, `--suite=Unit` included. It is green locally
because the directory exists on disk from earlier work. Before publishing,
run `git ls-files` against every path mentioned in `testo.php` and confirm
there is ≥1 committed file; the fix is a real test/bench class, not a
`.gitkeep` (testo scans for real classes, `.gitkeep` does not help).
**Status:** active

### ER-011 — psalm must scan `src` only — scanning `tests/` breaks prefer-lowest

**Source:** CI-gotcha investigation across several packages
**Rule:** If `psalm.xml` scans `tests/` (rather than `src` alone), the
`prefer-lowest` CI job fails on dozens of `PossiblyUnusedMethod` findings on
`#[Test]` and data-provider methods — the lower-bound psalm+plugins
combination does not recognise them as "used" the way the pinned/latest
combination does. The convention: `findUnusedCode="false"`, no
`psalm/plugin-phpunit` (Testo is not PHPUnit), scan `src` only.
**Status:** active

### ER-012 — `roave/backward-compatibility-check` needs `ext-bcmath`+`ext-intl` pins, and stays latent until the first post-v1 tag

**Source:** CI-gotcha investigation across several packages
**Rule:** `composer.json` needs `config.platform: {ext-bcmath, ext-intl}` —
otherwise `composer install`/`build` fails on a bare `composer:2` image; the
`compatibility` CI job needs those extensions too, because roave genuinely
uses them — this is not cargo cult. Separately: the BC-check job in
`build.yml` only really runs `composer bc-check` when `git describe --tags`
finds a previous tag — which means a package **without** the
`bc-check`/`release-check` scripts, the roave dependency and those platform
pins is green on the first release (no tag yet → skip) and fails on the very
next push to `master`, once a tag exists. Carry the full set from day one,
not reactively.
**Status:** active

### ER-013 — Diagnose CI psalm/prefer-lowest on the real floor PHP version, not on the local composer:2

**Source:** CI-gotcha investigation across several packages, `duration`, `yii3-clickhouse-toolkit`
**Rule:** The local `composer:2` image runs PHP 8.5. psalm under
`prefer-lowest` (6.16.0, say) can fail there because an old transitive
dependency (`amphp/cache` v2.0.0) carries an implicit-nullable parameter that
PHP 8.4+ turns into a deprecation, which psalm's strict preloader escalates
to fatal — a false negative specific to 8.5, since the real `prefer-lowest`
CI job runs PHP 8.3, where the deprecation never fires. Separately: because
`composer.lock` is gitignored, a package with a long-installed `vendor/` can
stay pinned to the broken `amphp/cache` version while a freshly installed
neighbour on the same image is green — diagnose by comparing
`vendor/composer/installed.json` between packages, fix with a plain
`composer update`, and do not blame the image. Check the real floor job
locally via `docker run --rm -v "$PWD":/app -w /app php:8.3-cli-alpine ...`
or equivalent, not composer:2.
**Status:** active

### ER-014 — A PHP 8.5-only CI matrix breaks prefer-lowest by design — do not chase it as a bug

**Source:** CI-gotcha investigation across several packages
**Rule:** When a package's matrix is PHP 8.5 only (`yii3-respect-validation`
requires ≥8.5, for instance), prefer-lowest legitimately downgrades psalm's
transitive dependencies to implicit-nullable-era releases, and psalm's
preloader genuinely fails — unlike the floor-8.3 case above (ER-013), here CI
*really does* resolve old versions, it is not an artefact of a stale vendor.
Fix with floor pins in `require-dev` on the culprits (`amphp/*`,
`daverandom/libdns`, `spatie/array-to-xml`, `netresearch/jsonmapper`,
`danog/advanced-json-rpc`, `revolt/event-loop` — the exact floor versions are
recorded per package), diagnosing iteratively (run lowest, grep `Uncaught`,
pin, repeat). Also drop the non-existent `PHP 8.3`/`PHP 8.4` contexts from
the required checks in branch protection for such a package — otherwise every
PR is blocked forever.
**Status:** active

### ER-015 — A `^X.0` dependency constraint is an unverified claim — always run a real prefer-lowest

**Source:** CI-gotcha investigation across several packages
**Rule:** New packages copy floor constraints like `^2.0` from their
neighbours while coding against today's release; only the prefer-lowest CI
job notices the gap. Concrete failures caught this way: `yiisoft/log ^2.0`
declared while the `ContextProvider\*` API in use only appeared in 2.1.0
(require-checker `Unknown Symbol`); `rasuvaeff/property-testing ^2.0`
declared while `Gen::stringFrom()` only appeared in 2.1.0 (runtime `Call to
undefined method`, which no static analysis catches). Before pushing,
actually run `composer update --prefer-lowest --prefer-stable && composer
build`. Two local gotchas while doing so: (1) after `composer update` the
`vendor/` tree may be stale relative to the new lock — re-run
`composer install` and check vendor before believing a floor "failure";
(2) local psalm-on-8.5 artefacts (ER-013) can make a genuine floor pass look
like a failure — confirm against a real 8.3 image before concluding anything
in either direction.
**Status:** active

### ER-016 — `[BC] SKIPPED` in roave is not a real pass; two known causes and the fix

**Source:** `rector-named-literals`, `yii3-mcp-audit-log-bridge`, the id-generation rollout across a package group
**Rule:** `roave/backward-compatibility-check` reports `[BC] SKIPPED` (not a
real pass) when it cannot compile or reflect a symbol — a package with a
files-only composer autoload (rector rules using rector's own scoped
autoloader, for example) gets SKIPPED on every `AbstractRector`-derived
symbol; a constructor default of the form `= new X()` produces "Unable to
compile initializer" → `[BC] SKIPPED` on every future run. CI must tolerate
SKIPPED-only findings as passing (real breaking-change detection keeps
working for everything else), but it is better to avoid the *cause*: use
`?X $x = null` plus resolution inside the constructor instead of `= new X()`
as a default — that sidesteps the SKIPPED classification entirely and gives
you a real check. Separately: roave compares **committed** revisions, not the
working tree — running `bc-check` before committing reports "no changes" and
proves nothing.
**Status:** active

### ER-017 — One-time build of a local pcov+intl image; two different "ignore" mechanisms in Infection

**Source:** local mutation run
**Rule:** `composer build` never runs mutation testing (`composer mutation`
lives only in the "Coverage & Mutation" CI job), and the bare `composer:2`
image carries neither a coverage driver nor `ext-intl`, so
`composer mutation`/`composer test:coverage` fail locally as-is — build a
reusable image once (`apk add $PHPIZE_DEPS icu-dev; docker-php-ext-install
intl; pecl install pcov; docker-php-ext-enable pcov`, committed as e.g.
`composer-pcov:local`) instead of repeating the install. Separately:
`global-ignore` and per-mutator `ignore` in Infection (matched via `fnmatch`
against `Class`, `Class::method` or `Class::method::<line>`) **prevent the
mutant from being generated** (the total count drops); per-mutator
`ignoreSourceCodeByRegex` does **not** reduce the count — it filters at test
time by matching the removed line of the mutation diff through
`/^-\s*<regex>$/mu`, so the regex must match the **whole** removed source
line, not a substring (a bare `"is_done"` silently matches nothing). Prefer
line-scoped `ignore` over regex filtering. Equivalent and unkillable mutants
recur in predictable shapes across packages: `max(0, x ?? 0)` (`?? -1` yields
the same result), redundant casts on already-typed JSON values, `sort()`
after `glob()` (glob already sorts), real-time polling loops, `match(true)`
with a constant subject (pcov reports such a `TrueValue` mutant as
"uncovered"). When a gate would require ignores, it is cleaner (per the
user's preference) to lower `minMsi` to the honestly reached ceiling than to
add ignores.
**Status:** active

### ER-018 — Redis Cluster: `redis-cli --cluster create` returns before the cluster is ready

**Source:** `circuit-breaker`
**Rule:** `redis-cli --cluster create` in a CI service-container setup returns
before the cluster is actually able to serve requests — the very next test
gets `CLUSTERDOWN`. `build.yml` must poll `cluster info` for
`cluster_state:ok` (60×1s, say) after `create`, before running any Redis
Cluster integration test.
**Status:** active

---

## Docker / monorepo mechanics

### ER-019 — Building path-repo neighbours in Docker requires mounting the monorepo root, not just the package directory

**Source:** mounting the monorepo root for composer (independently confirmed across several sessions)
**Rule:** A package with `repositories: {type: path, url: ../sibling}` fails
with "the url supplied for the path repository does not exist" when only the
package directory is mounted (`-v "$PWD":/app`) — the relative path resolves
against the parent, which exists inside the container only if the monorepo
root is mounted. The fix:
`docker run --rm -v "$PWD":/repo -w /repo/<pkg> composer:2 sh -c 'git config --global --add safe.directory "*"; composer build'`,
run from the monorepo root. A bare `path` repository with no explicit version
pin reports `dev-master`, which fails a constraint like `^1.0` even against a
real tag — inject `options.versions` explicitly for local builds, then revert
it before committing (the published composer.json must stay free of
path repos).
**Status:** active

### ER-020 — `composer.lock` is gitignored monorepo-wide — the "local lock dance" after editing composer.json

**Source:** CI-gotcha investigation across several packages
**Rule:** Since `composer.lock` is not committed, after editing
`composer.json` a local `composer validate --strict`/`composer normalize
--dry-run` fails until the lock is regenerated — the order is
`composer install`, then `composer normalize`, then `composer update --lock`,
and only then `composer build`. CI is unaffected (a fresh clone has no stale
lock) — this pitfall is purely a local iteration artefact, not a real CI
signal.
**Status:** active

### ER-021 — DNS inside the composer:2 container is flaky enough to need retries or `--network host`

**Source:** `SKILL.md` distribution across packages (a 19-package rollout), the `yii3-mcp-audit-log-bridge`/`telemetry-bridge` sessions
**Rule:** `composer install`/`update` inside the `composer:2` image sometimes
fails to resolve DNS (curl error 6/28) for Packagist or GitHub — often enough
across a large batch of operations that bare retries are not sufficient. Fix
with `--network host` or `--dns 8.8.8.8` on `docker run` for bulk or scripted
composer operations spanning many packages.
**Status:** active

### ER-022 — `composer install` in Docker runs as root — clean the temp directory with a container, not a bare host-side `rm -rf`

**Source:** `bin/verify-clean-clone` (2026-07-26), generalises beyond that one script
**Rule:** Any script that mounts a directory into the `composer:2` image and
runs `composer install` there ends up with a `vendor/` owned by the
container's root on the host — a subsequent bare `rm -rf` by the calling
(unprivileged) user fails with `Permission denied` on most files, and since a
failed `rm -rf` inside an `EXIT` trap does not by itself force the main
script to report failure, this can silently leave root-owned litter in `/tmp`
while the script reports success. Clean up the same way the files were
created: `docker run --rm --entrypoint rm -v "$dir":/cleanup composer:2 -rf
/cleanup` — note that the `composer:2` image's default entrypoint is
`composer`, so `rm` has to be passed through `--entrypoint`, otherwise it is
interpreted as `composer remove`.
**Status:** active

### ER-023 — `grep -r`/`rg` from the monorepo root silently skips every nested package repo

**Source:** the stale local master incident
**Rule:** The root `.gitignore` ignores everything outside a small whitelist
(`.claude/`, `bin/`, `templates/` and so on), and a bare `grep -r`/`rg` from
the root honours that ignore file — an "across all packages" sweep silently
returns almost nothing, never descending into the ~56 nested package
directories. Use `grep -rl … */` (an explicit glob bypasses the ignore for
that pass) or `rg --no-ignore` for any monorepo-wide grep or sweep.
**Status:** active

### ER-024 — Local package clones are frequently stale — refresh before branching OR auditing

**Source:** the stale local master incident
**Rule:** Local `master` checkouts of the `rasuvaeff/*` package repos
regularly lag behind `origin/master` (Dependabot merges on GitHub, the local
clone is never pulled). Branching a feature off stale local state produces a
PR that GitHub marks `CONFLICTING` (usually in
`composer.json`/`.github/workflows/*.yml` — exactly what Dependabot touches).
The same staleness invalidates not only branching but **audits**: a
monorepo-wide grep for a known bug once showed 13 affected packages; after
`git fetch`, 11 of them had already been fixed by an earlier sweep — the real
scope was a single file. Always `git fetch origin -q && git checkout -B
<feature> origin/master` before branching, and for a sweep use
`git -C <pkg> show origin/master:<file>`, never the working copy.
**Status:** active

### ER-043 — Red CI with untouched code and a gitignored lock means upstream; check the versions from the CI log before editing the package

**Source:** `rector-datetime-immutable` PR #7 (2026-07-28 session), the `rector/rector` × `phpstan/phpstan` incident
**Rule:** `composer.lock` is not committed (ER-020), so every CI run resolves
fresh transitive versions while the local `vendor/` may be a month old.
Consequence: a green local `composer build` is **not** evidence of a green
CI, and red CI on a PR that touches neither `src` nor `tests` (typically a
Dependabot `actions/*` bump) almost always means an upstream regression, not
a problem with the PR. Do not start by editing package code or bending tests
to the new expectations.

Diagnostic order: pull the actual versions out of the failing job's log
(`gh run view --log-failed` is often empty on such runs — fetch via
`gh api repos/<owner>/<repo>/actions/jobs/<jobId>/logs` and grep with `-a`,
the log counts as binary) → compare against `vendor/composer/installed.json`
→ reproduce with a pin (`composer update <pkg>:<version>
--with-all-dependencies`) → if upstream has already shipped a fix,
`gh run rerun <runId> --failed` with no package changes at all.

**Isolate the variable; do not stop at "two versions moved".** Between the
green baseline and the red CI both packages usually move at once, and "A is
to blame" ↔ "B is to blame" fit such data equally well. Pinning one while
holding the other fixed is the only thing that separates them:

| rector | phpstan | result |
|---|---|---|
| 2.5.5 | 2.2.5 | PASS (the original green baseline) |
| 2.5.5 | **2.2.6** | **FAIL** ← rector held, phpstan breaks it |
| 2.5.7 | 2.2.6 | FAIL (the combination from CI) |
| 2.5.8 | 2.2.6 | PASS (rector adapted) |

Symptom marker: `Prefer lowest` **green** while the whole main matrix is red
is a reliable sign that fresh upper bounds are breaking things, not the code.
Jobs that never invoke the affected tool (psalm, bc-check) also stay green
and do not muddy the picture.

The incident itself: `rector/rector` reaches by reflection into the private
`$container` property of **someone else's** class `PHPStan\Parser\RichParser`
(`PHPStanContainerMemento::removeRichVisitors()`, called from the
`RectorParser` constructor). `phpstan/phpstan` 2.2.6 removed that property →
any rector ≤ 2.5.7 dies fatally (`MissingPrivatePropertyException`, exit 255)
while initialising the parser; 2.5.8 adapted. Packages whose tests spawn a
real rector process (`rector-named-literals`, `rector-datetime-immutable`)
catch this as a cascade: the fatal lands on stdout instead of the expected
output, and the tests report not a meaningful diff but `expected 0, got 1`
and `JsonException: Syntax error` — those assertions hide the root cause,
which has to be dug out of the `Meaning: rector process failed:` line of the
same log. The rector↔phpstan pair is coupled through private internals, so a
phpstan patch release can break rector; on a repeat, do not pin reflexively —
first check whether a fresh rector is already out.
**Status:** active

---

## Config-plugin / DI

### ER-025 — `config/di.php` is invisible to cs, psalm and the unit suite — cover it with a dedicated ConfigWiringTest

**Source:** the `config/di.php` DI-wiring test
**Rule:** `config/di.php` is scanned by neither cs (Finder = src/tests) nor
psalm (src only) nor the phpunit/testo unit suite — a broken binding or an
accidental duplicate key between a core package and its backend sails through
`composer build` silently. Add a `tests/Integration/ConfigWiringTest.php`
(`#[CoversNothing]`) that: `require`s the package's own `config/di.php`
inside a method whose `$params` argument is captured by the closure via
`use ($params)` (`require` shares the caller's scope), then invokes the
returned factory closures to verify that the intended concrete class resolves
on every params branch; and also `require`s the vendored `config/di.php` of
the **core package** and asserts `array_intersect_key(coreDefs, backendDefs)
=== []` — a non-empty intersection is exactly what triggers the
`yiisoft/config` `Duplicate key` error at runtime. Supply dependencies via
the `yiisoft/test-support` doubles (`SimpleContainer`, `MemorySimpleCache`) —
`::class` references in di.php are compile-time strings that require no
autoloading, and merge/require never invokes the closures, so unrelated
provider classes need not exist.
**Status:** active

### ER-026 — Use the PSR doubles from `yiisoft/test-support` instead of homemade ones; PSR-16 reserves `:` in cache keys

**Source:** the PSR doubles from `yiisoft/test-support`
**Rule:** Prefer the `yiisoft/test-support` (`^3.0`) doubles —
`SimpleCache\MemorySimpleCache` (PSR-16, `getValues()`, clones stored objects
so assertions go by field rather than identity), `Log\SimpleLogger`,
`Container\SimpleContainer` (PSR-11) — over homemade fakes; it is idiomatic
for the Yii3 ecosystem and means less bespoke test code. `MemorySimpleCache`
actually **enforces** PSR-16 key validation and rejects the reserved
characters `{}()/\@:` — cache keys must be dot-separated (`<ns>.v<ver>.<key>`,
for example), not colon-separated; this independently caught
`yii3-settings`, `yii3-feature-flags-db` and `yii3-settings-db` before the
fix. A separate gotcha: `yiisoft/test-support` does not itself declare
`provide: psr/simple-cache-implementation`, so a package depending on
`yiisoft/db` (which virtually requires that provider) still needs
`yiisoft/cache` in `require-dev` even when only the test double is used. It
also cannot be made to throw on a *valid* key — keep a small custom throwing
PSR-16 double alongside it to cover non-fatal-catch branches when `minMsi`
demands it.
**Status:** active

---

## Packages with migrations (`*-db`)

### ER-027 — see the root `AGENTS.md` § "Packages with migrations (`*-db`)"

**Source:** the nine `*-db` packages' 2.0.0 rollout (migration table naming)
**Rule:** The full table of rules (namespace placement of migrations, a typed
table-name VO instead of a scalar, a single source for the name, identifier
validation only in the VO, derived index names, one VO shared by all of a
package's migrations, `setSourceNamespaces()` instead of `setSourcePaths()`,
an FQCN change means a major plus `UPGRADE.md`, testing through a real
`Injector`, tests must assert columns and indexes) lives in `AGENTS.md` —
those are principles with rationale and do not belong here. This ER is only
an anchor/pointer plus the related operational pitfalls of the migration,
added below (ER-028, ER-029).

⚠ The "`setSourceNamespaces()` instead of `setSourcePaths()`" item **does not
work** — see ER-044. Namespace-based registration silently finds not a single
migration in all nine `*-db` packages. Until upstream is fixed, do not
document it to users as a working recipe.
**Status:** active

### ER-028 — Stale `.php-cs-fixer.php` Finder after `migrations/` is removed

**Source:** the table-naming rollout across the nine `*-db` packages
**Rule:** Most `*-db` packages, after moving migrations into `src/Migration/`,
still list `__DIR__ . '/migrations'` in the `.php-cs-fixer.php` Finder — the
directory is gone and `cs` fails. Drop the line as part of the move.
**Status:** active

### ER-029 — `composer test` runs Unit only; an integration test still pointing at the old migration path stays green under it

**Source:** the table-naming rollout across the nine `*-db` packages
**Rule:** `composer test` is `--suite=Unit` only; `composer mutation` runs all
suites. An integration test still doing `require_once .../migrations/X.php`
after the move to `src/Migration/` stays green under the first and fails
under the second. Run `vendor/bin/testo --suite=Integration` explicitly when
moving migrations; do not rely on `composer test`/`build`.
**Status:** active

### ER-044 — `setSourceNamespaces()` does not find `*-db` package migrations: `db-migration` matches PSR-4 by string prefix and lands in the core package

**Source:** reference-application build, 2026-08-01 (investigation of broken migration namespace discovery)
**Rule:** Migration registration through
`MigrationService::setSourceNamespaces()`, documented in the README of all
nine `*-db` packages, **silently finds nothing** whenever the core package is
installed — that is, always, since the `-db` package depends on the core.

`MigrationService::getNamespacePath()` (`yiisoft/db-migration` 2.0.1) resolves
a namespace to a directory like this: it takes the **first**
`composer/autoload_psr4.php` entry the namespace starts with, comparing
against the key with its trailing `\` stripped, then cuts the remainder by
the **unstripped** key length. Stripping the separator erases the segment
boundary, so a namespace *sibling* looks like a parent. Composer emits
`Rasuvaeff\Yii3AbTesting\` before `Rasuvaeff\Yii3AbTestingDb\`, and the
string `"Rasuvaeff\Yii3AbTestingDb\Migration"` starts with
`"Rasuvaeff\Yii3AbTesting"` → the path resolves into the core package and
yields `vendor/rasuvaeff/yii3-ab-testing/src/b/Migration` (note the stray
`b/` fragment). No such directory exists, and discovery skips non-existent
directories via `if (!is_dir($path)) continue;` — without a single message.
The result: `migrate:up` prints "Your system is up-to-date", **exits 0 and
creates no tables at all**, and the failure surfaces later at runtime as
`relation ... does not exist`.

**All nine** `*-db` packages are affected — verified by a script over their
composer.json files: in every pair the core namespace is a string prefix of
the `-db` package's namespace (`Yii3Settings`/`Yii3SettingsDb`, and likewise
AuditLog, FeatureFlags, Tenancy, Workflow, Idempotency, Webhooks, AbTesting,
Outbox), every one keeps its migrations in `src/Migration/`, and every one
depends on its core. This follows from the naming convention; it is not
coincidence.

`setSourcePaths()` is not a workaround: discovery substitutes an empty
namespace for those and looks for unqualified class names, which do not
autoload. A PSR-4 entry of the application's own composer.json does not help
either — composer still emits the parent namespace first.

Why it was never caught: `MigrationTableNameTest` and `MigrationTest` build
migrations directly through `Injector::make()`. **No test exercises the
documented discovery path.** The general rule: a scenario the documentation
promises the user must be exercised by a test exactly as documented, not
through an equivalent bypass.

For contrast (verified on a real application outside the monorepo): an
application's own migrations under its own root namespace plus
`setSourceNamespaces()` work, because that namespace really is a parent;
`yiisoft/rbac-db` migrations plus `setSourcePaths()` work, because those are
**global classes with no namespace** — the very scheme our packages moved
away from in v2.0.0 for the sake of autoloading and table-name VO resolution.
Our packages are the only case left without a working mechanism.

Not yet fixed in a **release**. The workaround is to apply migrations in a
loop through `Injector::make($class)->up($builder)` (the way the packages'
own tests do it), listing the migration classes explicitly instead of
namespace discovery:

```php
foreach ([M0001CreateSomething::class, M0002AddIndex::class] as $class) {
    $injector->make($class)->up($builder);
}
```

**Update 2026-08-01:** upstream master already fixes the scenario as a side
effect — PR yiisoft/db-migration#341 (merged 2026-05-20, closing issue #338
about path↔namespace, not our bug): `getNamespacePath()` now skips a
candidate whose directory does not exist and keeps walking the PSR-4 map
(reaching the `*-db` package's exact entry), and on total failure throws a
`LogicException` instead of returning a silent zero; the new
`loadMigrationClasses()` does a `require_once` and matches
`class_exists($namespace.'\\'.$class)` against every configured namespace.
Verified by a live repro (settings-db v2.0.1 + sqlite): `2.0.1 → found: 0`,
`dev-master → found: 1` (the correct FQCN). But there is no release with the
fix — the latest tag is 2.0.1 (2025-12-20), so users on `^2.0` stable are
still broken.
**Status:** active (waiting for an upstream release; after it, re-verify and lift the ban on documenting the recipe)

---

## Yii3 / library-specific pitfalls

### ER-030 — PHP-FPM has no preemption — a PSR-18 timeout decorator cannot enforce a deadline

**Source:** the analysis of why a time-limiter is not viable under FPM
**Rule:** While a synchronous FPM worker is blocked inside `sendRequest()`, no
PHP code executes at all, so a wrapper can only measure elapsed time *after*
the call returns — far too late to abort. PSR-18 has no per-request timeout
hook for a decorator, `set_time_limit` ignores blocking I/O, and
`pcntl_alarm` is unavailable/unreliable under FPM and would not interrupt a
blocking cURL syscall. The correct fix for HTTP timeouts is configuration of
the concrete PSR-18 client itself (Guzzle `timeout`/`connect_timeout`,
Symfony HttpClient `timeout`/`max_duration`) — an architectural decision, not
a missing package; do not propose a generic `time-limiter` /
pessimistic-timeout package for an FPM-first ecosystem.
**Status:** active

### ER-031 — Async telemetry/metrics flush under FPM must go through `register_shutdown_function`, and strictly AFTER the response is sent

**Source:** the observability-stack plan
**Rule:** `new TracerProvider()` (and the equivalent OTel SDK constructions)
registers no automatic shutdown flush, and PHP-FPM has no worker-shutdown
hook — buffered spans and metrics are silently lost when the worker is
recycled unless the integration registers a per-request
`register_shutdown_function` flush (or disables batching). Separately: a
naive shutdown flush that fires before the connection closes noticeably slows
the client down — the Yii3 SAPI emitter never calls
`fastcgi_finish_request()`, so the flush holds the worker (and, transitively,
the tail the client sees) until the response is delivered. The fix:
`fastcgi_finish_request()` first, flush *afterwards*, moving the cost of
export off client latency and onto pure worker throughput (measured: 443ms
median full request → 147ms, i.e. below the untraced baseline, because an
early finish also cuts off the application's own post-response shutdown
tail).
**Status:** active

### ER-032 — An OTel metric instrument's identity includes the description, not just the name

**Source:** the observability-stack plan
**Rule:** Looking up the same counter/histogram/gauge by name but with a
different (or missing) `help`/description text creates a **second**, separate
metric stream instead of reusing the first — instrument identity in the OTel
SDK is name plus description together. Any adapter wrapping OTel metrics must
memoise its own wrapper objects by name (first help/buckets win) to get
Prometheus-style "one stream per name" semantics; this reversed an earlier
assumption that "counters and histograms need no memoisation, only gauges do"
once that turned out to be wrong.
**Status:** active

### ER-033 — Do not trust `getSize()` on `php://input` or real SAPI streams

**Source:** the observability-stack plan (found live on a real application, POST parameters were silently vanishing)
**Rule:** A PSR-7 stream wrapping `php://input` on a real SAPI (not a test
double) may return `null` or `0` from `getSize()` even when the body does
contain data — a read based on that size silently discards the body. Read
with an explicit byte limit instead of trusting `getSize()` in any code that
really captures or masks a request body (parameter-logging middleware, for
instance).
**Status:** active

### ER-034 — Do not assume the `yiisoft/validator` family defaults to a container-backed resolver — check the real one

**Source:** `yii3-recaptcha` v2
**Rule:** `yiisoft/validator` rule-handler resolution uses
`SimpleRuleHandlerContainer` **by default** (a bare `new`, no DI), not a
container-backed resolver — an earlier design that made the handler's
constructor dependencies mandatory broke on a real consumer application with
`ArgumentCountError`, because the assumption "container-backed is the Yii3
default" was simply false. The robust fix pattern: make the handler's
constructor dependencies **optional**, with a fallback to a static registry
populated by the package's own config-plugin bootstrap — that works
identically under the real default (bare `new` → registry fallback, zero
configuration) and under a container-backed resolver (injected dependencies
win). Verify any "the Yii3 default is X" assumption about a yiisoft/*
component against the component's actual source and tests before designing a
DI story around it.
**Status:** active

### ER-035 — `symfony/workflow` integration gotchas: event-dispatcher type mismatch, triple event dispatch, one source per transition

**Source:** `yii3-workflow`
**Rule:** Symfony's `Workflow` types its own
`Symfony\Contracts\EventDispatcher\EventDispatcherInterface`
(name-aware dispatch), not PSR-14 — a bridge adapter is unavoidable when the
host framework (Yii3) uses PSR-14; the package must require the lightweight
`symfony/event-dispatcher-contracts`, never the full
`symfony/event-dispatcher`. Every workflow event fires **three times**
(generic, per-workflow, per-transition) — a naive bridge that forwards all
three makes class-based PSR-14 listeners fire three times for one logical
transition; forward only the generic name. A `state_machine` transition
accepts exactly one source place — a configuration shortcut like
`from: [a, b]` must be expanded into one transition per source, otherwise
Symfony silently never enables the transition at all (caught only by running
Symfony's own `StateMachineValidator`/`WorkflowValidator`).
**Status:** active

---

## Process / agent pitfalls

### ER-036 — An MCP tool for a local coding agent is only valuable if it exposes runtime state unavailable from the filesystem

**Source:** the post-mortem of the deleted dev-tools package
**Rule:** A package of MCP tools for a local AI coding agent (which already
has filesystem and shell access) was deleted after failing the consumer-value
test: 3 of its 5 tools (`classes.locate`, `logs.recent`, `app.info`) merely
duplicated grep/tail/file-read, worse than the agent's native tools. The only
tools that carried value were those exposing genuine runtime state — the live
database schema, merged DI/params after config-plugin resolution, registered
console commands. Generalised for any future MCP-tool package aimed at a
coding agent as its consumer: scope it strictly to "data the agent cannot
obtain from the files it can already read"; a tool that is just a nicer
wrapper around grep/cat/tail is a signal that it should not exist.
**Status:** active

### ER-037 — Verify escaping and argument-assembly claims empirically against the real external binary, not with string-level unit tests alone

**Source:** `media-converter`
**Rule:** When wrapping an external CLI tool with its own escaping/quoting
rules (ffmpeg filtergraphs in this case), a purely string-level PHP unit test
can pass while the real invocation is wrong — two real bugs (single vs double
escaping of a colon, which the filter's own re-split misinterpreted; a
literal `'` silently disappearing under every escaping scheme tried) were
caught only by actually running the assembled argv through the real binary
and checking the output and exit code. Do that verification through a real
subprocess call from a scripting language with a native argv array (Python's
`subprocess.run([...])`, for example), not bash — bash quoting consumes a
layer of escaping itself and gives false readings about what the target
program actually received.
**Status:** active

### ER-038 — A failed `cd X && ...` chain leaves the shell's cwd unpredictable — never rely on an assumed cwd after a failure

**Source:** `yii3-mcp`, `media-converter` (independently twice)
**Rule:** When a compound Bash call `cd <dir> && <command>` fails partway
through (the `cd` itself did not take, or a later command in the chain
failed), the working directory inherited by the *next* tool call is not
necessarily "where we started" or "where it was expected" — one incident came
close to touching the composer.json of an entirely different package on
`master` exactly this way, and was caught only by the resulting composer
error. Prefer absolute paths (or `-C <dir>` / an explicit `-w` in Docker
invocations) over assumptions about cwd across separate tool calls,
especially right after any command that may have failed.
**Status:** active

### ER-039 — File edits made inside a Docker container (`cs:fix`/`rector:fix`) are worth re-checking in the same or the immediately following call

**Source:** `yii3-mcp` (the rbac-bridge session)
**Rule:** In one observed session `docker run ... composer rector:fix`
reported 5 files changed, but 3 of them turned out unchanged when read in a
later, separate Bash call — as if the edit had not been persisted (or had
been reverted by something afterwards). The exact cause was never
established, but the practical mitigation worked: when the result of a
container-side `:fix` script must definitely persist, check it with
`git diff`/`cat` in the *same or the immediately following* tool call rather
than trusting that the earlier command took effect and stuck; and if the fix
absolutely has to land, consider applying it directly with Edit instead of a
container-side auto-fixer.
**Status:** active

### ER-040 — `bin/package-audit`'s examples check only recognises a script named as a bare backticked name in the README table

**Source:** `yii3-mcp`
**Rule:** The `examples/README.md` parser in `bin/package-audit` recognises
the script cell of the Script column only as a plain markdown code span
`` `name.php` `` — a markdown link to the same file (`[name.php](name.php)`)
does not match the basename pattern, so the script is treated as lint-only
and never actually executed, without a single visible error. When adding an
example, use the bare backtick form in the Script column, otherwise the audit
silently loses coverage for it.
**Status:** active

---

## Claude Code hooks (2026-07-26)

### ER-041 — A `PreToolUse` hook sees the state BEFORE the command runs — target-directory resolution must account for paths that do not exist yet

**Source:** the LLM-autonomy plan, the `pre-commit-audit.sh` implementation
**Rule:** `PreToolUse` fires *before* the gated Bash command executes. A single
tool call that both creates a directory (`mkdir`/`git init`) and immediately
acts inside it (commits, say) presents the hook with a target that does not
exist on disk yet — a hook that `cd`s into the target to resolve it gets
nothing and silently passes, which reads as "the safeguard did not fire" when
in fact its premise (the directory already exists) was simply not true yet.
Compound Bash commands reach the hook as ONE `tool_input.command` string with
real embedded newlines, not split into events per the instruction — so a hook
that parses shell state (tracking `cd`, for instance) must walk the segments
separated by `&&`/`;`/newline itself, in order. A segment like `cd "$VAR/sub"`
referencing an unexpanded shell variable is fundamentally unresolvable by a
textual parser (there is no real shell execution) — such a hook must
fail closed (deny with an explanation) rather than silently resolving to a
non-existent path, which would otherwise read as an allow and quietly nullify
the safeguard.
**Status:** active

### ER-042 — A hook scanning a command for dangerous patterns must strip heredoc bodies before matching

**Source:** the LLM-autonomy plan, the `bash-guard.sh` implementation
**Rule:** A hook that greps the whole `tool_input.command` string for
dangerous patterns (`rm -rf`, `git push --force`) produces a false positive on
`git commit -m "$(cat <<'EOF' ... EOF)"` whose commit-message body merely
*mentions* those words in prose — heredoc content is data, not executable
code, and scanning it as shell instructions yields a self-inflicted block on
a command that was safe to begin with. Strip heredoc bodies (`<<'EOF' ...
EOF`, `<<-EOF ... EOF` and so on) from the text before running any
danger-pattern scan, leaving the code outside the heredoc scannable — a
genuinely dangerous command placed before or after the heredoc must still be
caught.
**Status:** active

### ER-045 — A schema test that only checks column presence misses a wrong type: SQLite stores an unknown pseudo-type verbatim

**Source:** building a new `*-db` package on 2026-08-01, found in the published
`yii3-workflow-db` 2.0.1

**Rule:** the migration declared `'id' => 'bigprimarykey'`. No such token
exists in `yiisoft/db` — the real pseudo-type is `bigpk`, the typed equivalent
of `ColumnBuilder::bigPrimaryKey()`. Because of dynamic typing, SQLite writes
an unknown type into the DDL verbatim (`"id" bigprimarykey`) and never
complains: the table is created, the column is there, inserts succeed, but
there is no autoincrement and **every `id` reads back as `NULL`**. MySQL and
PostgreSQL reject the same DDL, so for users of those engines the package
broke right at migration time.

Why this survived both the tests and the release:

| Gap | What was there | What it should be |
|---|---|---|
| Schema check | `foreach ($columns) Assert::notNull($schema->getColumn($c))` — an unknown type satisfies that | Assert the property, not presence: `isPrimaryKey()`, `isAutoIncrement()` |
| Insert check | `insert()` listed every column except `id`, and nobody read `id` back | Read the generated values back: two inserts → two distinct positive `id`s |
| Driver matrix | Integration on SQLite only — the one engine that stays quiet | Either run MySQL/PG in CI, or assert the DDL explicitly: `SELECT sql FROM sqlite_master` contains no unknown tokens |

The general rule: **a column whose value the database generates must be read
back by at least one test.** An assertion that "the column exists" checks the
markup, not the behaviour, and on an engine with dynamic typing it checks
nothing at all.

Checked across every `*-db` package: only `yii3-workflow-db` is affected
(fixed, regression tests added and confirmed to fail against the old code);
the rest declare their primary keys as explicit
`string(...) NOT NULL PRIMARY KEY`.

**Status:** active

### ER-046 — `roave/backward-compatibility-check` permanently breaks the required BC status on an enum case / `new Expr()` default in a promoted readonly property

**Source:** the account-wide `release.yml` rollout, 2026-08-02 — three PRs
(`yii3-ab-testing` #20, `yii3-ab-testing-db` #13, `bulkhead` #12) stayed open
after the bulk merge; `bulkhead` turned out to be an ordinary flake
(a Redis Cluster integration test, green on a re-run), but the other two were
not.

**Rule:** `roave/better-reflection` (already on the current 6.72.0) cannot
statically parse the default value of a promoted readonly constructor
parameter when that default is an enum case (`DecisionReason::Assigned`) or a
`new` expression (`new ExperimentSchedule()`). It reports this as
`[BC] SKIPPED: ...` and **counts it as an incompatible change** — meaning
`composer bc-check` exits with code 3 on **any** comparison, including
`--from=<a tag identical to the current HEAD>` (verified locally twice:
diffing against itself yields the same SKIPPED report). This is not a
one-off bug introduced by a PR — it is a permanent state of the package: any
subsequent PR, whatever it contains, will be red on the required
`Backward compatibility` status forever, as long as the pattern stays in the
code.

Trying to "just remove" the pattern (un-promote the property, take a nullable
parameter and assign the default in the constructor body) was checked
empirically and **does not work** — the SKIPPED count did not drop, it rose
(2 → 3): better-reflection trips over an enum or `new` expression in the
constructor body too, just under a different message. Refactoring a public
constructor for the sake of a static analyser is the wrong lever and does not
solve the problem.

**The right fix is not the source, it is the gate itself.**
`roave/backward-compatibility-check` does have a baseline mechanism
(`.roave-backward-compatibility-check.xml` plus `<ignored-regex>`), but it is
suppression-style and forbidden by the "no suppressions, no baseline" rule
from `AGENTS.md` and the packages' golden rules. Instead, the
`Backward compatibility check` step in
`templates/.github/workflows/build.yml` (and in both affected packages) was
extended: if **every single** line of the report starts with `[BC] SKIPPED:`
(and none with `[BC] CHANGED:`/`REMOVED:`/`ADDED:`), that is treated as a
pass — SKIPPED means "the tool could not analyse this", not "it found a
break". One genuine finding of any other kind still fails the build. The line
format was confirmed against the source (`Change::__toString()`): `[BC] ` is
emitted only when `isBcBreak`, which for SKIPPED is always true
(`Change::skippedDueToFailure()`).

**Gotcha in the bash logic itself:** `grep -c` with no matches exits 1, which
under GitHub Actions' default `bash -eo pipefail` kills the script at the
variable assignment — the same class of bug had already been caught in other
scripts in this repository. You need `{ grep -cE '...' || true; }` — the group
swallows grep's error before `$(...)` sees it.

**How to apply:** any new package introducing an enum case or a `new Expr()`
as the default of a promoted readonly constructor parameter inherits this
landmine on the very first PR after the major carrying that code is
published. The template already contains the fix — simply do not revert that
block when hand-editing `build.yml`. Existing packages are patched
individually (a diff touching only `.github/workflows/build.yml`, a separate
PR, no release) when they actually hit it, rather than by a pre-emptive
account-wide retrofit.

**Status:** active
