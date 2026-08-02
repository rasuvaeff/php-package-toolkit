# AGENTS.md — package authoring rules

Instructions for AI agents creating new Composer packages in this monorepo.
File templates live in `templates/`, next to this document.

## Context

Every package is a PHP 8.3+ library published as `rasuvaeff/<name>` on Packagist.
Namespace: `Rasuvaeff\<PascalCaseName>`.
There is no PHP/Composer on the host — everything runs through Docker
(`composer:2` image).

## Required file set

| File | Source | Note |
|---|---|---|
| `composer.json` | `templates/composer.json` | Replace the placeholders |
| `.php-cs-fixer.php` | `templates/.php-cs-fixer.php` | Verbatim |
| `psalm.xml` | `templates/psalm.xml` | Add issueHandlers if needed |
| `infection.json5` | `templates/infection.json5` | Start at `minMsi` = 85, raise it as the package matures |
| `rector.php` | `templates/rector.php` | Verbatim |
| `.editorconfig` | `templates/.editorconfig` | Verbatim |
| `.gitignore` | `templates/.gitignore` | Verbatim |
| `.gitattributes` | `templates/.gitattributes` | Verbatim |
| `LICENSE.md` | `templates/LICENSE.md` | Verbatim |
| `CHANGELOG.md` | `templates/CHANGELOG.md` | Add `## 1.0.0 — YYYY-MM-DD` on release |
| `README.md` | Write from scratch | See "README.md structure" |
| `README.ru.md` | Write from scratch | Russian mirror of `README.md`. **Every edit to README.md must be mirrored here in the same commit** |
| `llms.txt` | Write from scratch | Compact API reference for LLMs |
| `AGENTS.md` | Write from scratch | See "Package AGENTS.md structure" |
| `CLAUDE.md` | Contents: `@AGENTS.md` | A single line |
| `testo.php` | `templates/testo.php` | Verbatim — Unit + Benchmarks suites, `src` for coverage |
| `.github/workflows/build.yml` | `templates/.github/workflows/build.yml` | Replace `{{PHP_EXTENSIONS}}` |
| `.github/workflows/static-analysis.yml` | `templates/.github/workflows/static-analysis.yml` | Replace `{{PHP_EXTENSIONS}}` |
| `src/` | Create | One class = one file |
| `tests/` | Create | `<ClassName>Test.php` for every class |
| `tests/Integration/` | Create | If tests against external services are needed |
| `benchmarks/` | Create | `<ClassName>Bench.php` — one class with `#[Bench]` per CPU-bound operation |
| `examples/` | Create | `README.md` plus example scripts |
| `build/` | `.gitkeep` | For coverage reports |
| `src/Migration/` | `*-db` only | `yiisoft/db-migration` migrations live under the package namespace, not in `migrations/`. See "Packages with migrations" |
| `UPGRADE.md` | Majors with manual steps | What the user must do by hand (SQL, config replacement) before upgrading |

## Template placeholders

| Placeholder | Description | Example |
|---|---|---|
| `{{PACKAGE_KEBAB}}` | Composer package name | `clickhouse-toolkit` |
| `{{PACKAGE_PASCAL}}` | Namespace segment | `ClickHouseToolkit` |
| `{{DESCRIPTION}}` | Package description | `"ClickHouse toolkit for PHP"` |
| `{{PHP_EXTENSIONS}}` | PHP extensions for CI | `json` or `mbstring, pdo_sqlite` |

## composer.json: conventions

### Required fields

```json
{
    "name": "rasuvaeff/<kebab-case>",
    "type": "library",
    "license": "BSD-3-Clause",
    "php": "8.3 - 8.5",
    "authors": [{"name": "Victor Razuvaev", "email": "rasuvaeff@gmail.com"}],
    "homepage": "https://github.com/rasuvaeff/<kebab-case>",
    "support": {
        "issues": "https://github.com/rasuvaeff/<kebab-case>/issues",
        "source": "https://github.com/rasuvaeff/<kebab-case>"
    }
}
```

### autoload

```json
{
    "autoload": {"psr-4": {"Rasuvaeff\\<Pascal>\\": "src/"}},
    "autoload-dev": {"psr-4": {"Rasuvaeff\\<Pascal>\\Tests\\": "tests/"}}
}
```

### config

```json
{
    "config": {
        "allow-plugins": {
            "ergebnis/composer-normalize": true,
            "infection/extension-installer": true
        },
        "sort-packages": true
    }
}
```

### Standard dev dependencies

```json
{
    "require-dev": {
        "ergebnis/composer-normalize": "^2.51",
        "friendsofphp/php-cs-fixer": "^3.95",
        "infection/infection": "^0.33",
        "maglnet/composer-require-checker": "^4.17",
        "rector/rector": "^2.4",
        "roave/backward-compatibility-check": "^8.0",
        "testo/bridge-infection": "^0.1.6",
        "testo/testo": "^0.10.25",
        "vimeo/psalm": "^6.16"
    }
}
```

Add extra dev dependencies only when integration tests need them (for example
`yiisoft/db-sqlite` for SQLite tests, `guzzlehttp/guzzle` for HTTP).

If the package contains code with algebraic laws or invariants (see
"Property-based tests"), add `"rasuvaeff/property-testing": "^1.0"` to
`require-dev` and `mbstring` to `extensions:` in every CI job.

### Scripts (identical set)

```
bench       — testo --suite=Benchmarks -vv (benchmarks from benchmarks/)
build       — the full gate: validate → normalize → require-checker → cs → psalm → test
bc-check    — roave-backward-compatibility-check
cs          — php-cs-fixer --dry-run --diff
cs:fix      — php-cs-fixer --diff
mutation    — infection --threads=max (testFramework: testo, needs the pcov/xdebug extension)
psalm       — psalm --no-cache
rector      — rector process --dry-run
rector:fix  — rector process
release-check — build → rector → bc-check
require-checker — composer-require-checker
test        — testo --suite=Unit
test:coverage — testo --suite=Unit --coverage --coverage-clover=build/coverage.xml
test:coverage:ci — testo --suite=Unit --coverage-clover=build/coverage.xml
```

`composer.lock` is gitignored (this is a library).

## Config plugin: DI and params (for core + backend pairs)

Rules for packages split into a core and pluggable backends
(`yii3-feature-flags` + `-db`/`-redis`, `yii3-settings` + `-db`). Breaking them
produces a `yiisoft/config` runtime error:
`Duplicate key "<FQCN>" while building "<group>"`.

| Rule | Details |
|---|---|
| The core does NOT bind the pluggable interface | The core binds only the facade (`FeatureFlags`, `Settings`). The interface (`FlagProvider`, `SettingsProvider`) is bound by exactly ONE source: a backend or the application (config-only) |
| One key, one vendor | `yiisoft/config` forbids two vendor packages from defining the same key in the same group (`di`/`params`). This is by design |
| The facade is built from an injection | `Settings`/`FeatureFlags` in the core receive the provider through DI (`static fn (SettingsProvider $p) => ...`) instead of constructing it internally |
| The backend binds its own interface | `-db` binds `FlagProvider`/`SettingsProvider` (plus `WritableSettingsProvider`); it does NOT bind the facade |
| config-only lives in the application | Without a backend the application binds `Interface => Config*Provider` itself in `config/common/di/*.php`. Document this in the core's README |
| App-side escape hatch (if needed) | `config-plugin-options.vendor-override-layer` is read ONLY from the root package; a vendor package cannot add itself there |

The model is the one `yiisoft/cache` uses: the core does not bind the pluggable
`Psr\SimpleCache\CacheInterface`, the backend does. Install the core plus exactly
one backend and it works with no application config. Install two backends at once
and you get a deliberate error (pick one).

Verifying the merge without publishing a new major: reproduce it through the real
`yiisoft/config` (a fake vendor layout plus a hand-written merge plan, run in
Docker with `composer:2 php`). `config/di.php` is covered by neither cs (Finder =
src/tests/examples), nor psalm (src-only), nor testo — `composer build` does not
validate edits to it. Check it with `php -l` and the merge harness.

## Packages with migrations (`*-db`)

The full rule table (namespace placement, typed table-name VO, single source of
the name, and so on) plus the pitfalls that come with moving migrations live in
`docs/evolved-rules.md`, ER-027, ER-028, ER-029.

⚠ **Registering migrations via `setSourceNamespaces()` does not work** in any of
the nine `*-db` packages: `yiisoft/db-migration` matches the PSR-4 map by string
prefix, lands in the core package, and `migrate:up` silently returns 0 without
creating any tables. Do not document this recipe for users until upstream is
fixed — details and the workaround are in `docs/evolved-rules.md`, ER-044.

## Code style

### Mandatory rules

1. `declare(strict_types=1);` in every file, right after `<?php`, then a blank line.
2. `final readonly class` by default. `final class` only when `with*` methods need `clone`.
3. `@api` on every public class/interface. `@internal` on internal utility classes.
4. `#[\Override]` on every implementation of an interface/parent method.
5. Named arguments at call sites: `column: 'age', value: 25, operator: '>'`.
6. Explicit return/param types everywhere.
7. Trailing comma in multiline arrays, arguments, parameters.
8. A blank line before `return`, `throw`, `try`.
9. One class = one file. File name = class name + `.php`.
10. Typed constants: `private const array VALID_OPERATORS = [...]`.
11. Psalm annotations are written up front, not after the first psalm error:
    `non-empty-string`, `int<0, max>`/`positive-int`, `list<T>` (not
    `array<int, T>`), `array{…}` shapes on `toArray()`, `@psalm-type` plus
    `@psalm-import-type` for a recurring shape (a DB row, a JSON payload),
    `@implements IteratorAggregate<int, T>`. Untrusted input is accepted as
    `array<string, mixed>` and narrowed inside. `@psalm-suppress` and baselines
    are forbidden. `@psalm-immutable` is optional and only for leaf VOs with no
    service dependencies; when `@psalm-pure` cascades through third-party code,
    drop the annotation instead of silencing it.

### Class template

```php
<?php

declare(strict_types=1);

namespace Rasuvaeff\PackageName;

use SomeDependency;

/**
 * @api
 */
final readonly class ClassName
{
    public function __construct(
        private string $field,
    ) {}
}
```

### Immutability

| Situation | Approach |
|---|---|
| Fully immutable | `final readonly class` |
| Needs `with*` methods via clone | `final class` + private properties + `clone` in `with*` |
| Builder with a terminal `build()` | `final class` with mutable internals, `private` constructor + `static create()` |

### Validation

- Validate in the constructor (operator whitelist, identifier format, range checks).
- `InvalidArgumentException` with a message that has no trailing period: `'Invalid operator "foo"'`.

## Tests

The framework is [Testo](https://php-testo.github.io) (`testo/testo`). Bench is
built in (`#[Bench]`); infection plugs in through `testo/bridge-infection`.

### Test class structure

```php
<?php

declare(strict_types=1);

namespace Rasuvaeff\PackageName\Tests;

use Rasuvaeff\PackageName\ClassUnderTest;
use Testo\Assert;
use Testo\Codecov\Covers;
use Testo\Data\DataProvider;
use Testo\Lifecycle\BeforeTest;
use Testo\Test;

#[Test]
#[Covers(ClassUnderTest::class)]
final class ClassUnderTestTest
{
    private ClassUnderTest $fixture;

    #[BeforeTest]
    public function setUp(): void
    {
        $this->fixture = ...;
    }

    public function scenarioDescription(): void
    {
        Assert::same($actual, $expected);
    }

    #[DataProvider('methodProvider')]
    public function scenarioWithProvider(mixed $arg1, mixed $arg2): void
    {
        Assert::same($actual, $expected);
    }

    public static function methodProvider(): iterable
    {
        yield 'case name' => [arg1, arg2];
    }
}
```

### Test rules

| Rule | Details |
|---|---|
| `#[Test]` | On the class — every public `void`/`never` method becomes a test |
| `#[Covers(Class::class)]` | On every test class (`Testo\Codecov\Covers`) |
| `#[DataProvider('method')]` | Parameterized tests (`Testo\Data\DataProvider`) |
| `yield 'name' => [...]` | Named cases in data providers |
| `Assert::same($actual, $expected)` | Strict comparison; **the `(actual, expected)` order is the reverse of PHPUnit's** |
| `Assert::false` / `Assert::true` / `Assert::null` | Boolean/null checks |
| `Assert::instanceOf($obj, Class::class)` | Type check (order: `actual, expected`) |
| `Assert::string($s)->contains($n)` | String checks (chains) |
| `#[BeforeTest]`/`#[AfterTest]` | setUp/tearDown through lifecycle hooks (`Testo\Lifecycle`); the method name is free |
| `#[CoversNothing]` | On integration tests |
| `<ClassName>Test` | File name = class name |

With `#[Test]` on the class, public methods returning `array`/`iterable`
(providers) do NOT become tests; neither do private helpers.

### Property-based tests

For code with algebraic laws and invariants, use `rasuvaeff/property-testing`
(a Testo plugin). A property test generates random inputs, hunts for a
counterexample and shrinks it.

**When to use it** (wherever hand-written cases cannot cover the input space):

| Invariant kind | Examples |
|---|---|
| Algebra / laws | commutativity, associativity, De Morgan, double negation, monad (`map` identity/composition) |
| Round-trip | `decode(encode(x)) == x`, `toMicros` ↔ factory |
| Idempotence | `normalize(normalize(x)) == normalize(x)` |
| Monotonicity / bounds | backoff delay ∈ `[0, cap]` and never decreases; rollout is monotonic in percentage |
| Determinism | hash bucketing: the same subject always yields the same variant |
| Aggregation | worst-of status does not depend on order |

Glue, DI, adapters, UI and plain DB mappers are **not** property-test material.

**How to write them** (NOT a separate file — methods go into the existing
`<Class>Test`, so `#[Covers]` is preserved):

```php
use Rasuvaeff\PropertyTesting\ArbitraryInterface;
use Rasuvaeff\PropertyTesting\Gen;
use Rasuvaeff\PropertyTesting\Property;

#[Property(runs: 300)]
public function delayStaysWithinCap(int $base, int $cap, int $attempt): void
{
    Assert::true((new ExponentialBackoff($base, 2.0, $cap))->delayMs($attempt) <= $cap);
}

/** @return array<string, ArbitraryInterface> */
public static function delayStaysWithinCapGenerators(): array
{
    return [
        'base' => Gen::intBetween(0, 10_000),
        'cap' => Gen::intBetween(0, 60_000),
        'attempt' => Gen::intBetween(1, 40),
    ];
}
```

| Rule | Details |
|---|---|
| `#[Property(runs: N)]` | The attribute from `Rasuvaeff\PropertyTesting\Property`; `runs` ≥ 1 (default 100) |
| Generators | A `public static function <testMethod>Generators(): array` returning `['arg' => Gen::...]` keyed by parameter name. **Strictly public static** (rector's `RemoveUnusedPrivateMethodRector` deletes private ones — they are only ever called through reflection; public is untouched by every rule, and it does not become a test because it does not return `void`). `public` without `static` only when the body needs `$this`. There is NO `#[Given]` attribute |
| `Gen::*` | `int`, `intBetween`, `intPositive`, `float`, `floatBetween`, `bool`, `string`, `stringAscii`, `stringOf`, `arrayOf`, `nonEmptyArrayOf`, `oneOf`, `nullable`, `map`, `flatMap`, `filter`, `tuple`, `frequency`; since 2.3.0 also `regex`/`stringMatching` (a PCRE subset), `ipv4`, `email`, `url`, `json` |
| `Gen::draw($arb)` | Since 2.4.0: an in-body draw inside the property body for several dependent values (when a nested `flatMap` gets unwieldy). Only valid inside a property run (otherwise `RuntimeException`); it shows up in the counterexample as `draw#N` |
| Construct, do not filter | Build dependent values (`$max = $n + $slack`) instead of discarding them through `Assume::that(...)` — otherwise a third of the runs is thrown away |
| `Assume::that(bool)` | Only when construction is impossible (it warns above 90% discards) |
| Helper generator | A `private static function xGenerator(): ArbitraryInterface` is fine — under `#[Test]` it does not become a test (it returns neither `void` nor `never`) |
| CI: `ext-mbstring` | property-testing requires `mbstring` (plus `random`, core). Add `mbstring` to `extensions:` in every job of `build.yml`/`static-analysis.yml`, otherwise a local `composer build` is green while CI is red |
| dev dependency | `"rasuvaeff/property-testing": "^1.0"` in `require-dev` |

### Integration tests

- They live in `tests/Integration/`; `testo.php` gains a `SuiteConfig` with
  `location: ['tests/Integration']`.
- Skip through env: check `getenv(...)` at the top of the test and `return` (or use an attribute).
- Setup is idempotent: `DROP TABLE IF EXISTS` at the start of `#[BeforeTest]`.
- Name: `<Tech>IntegrationTest` (for example `SqliteIntegrationTest`).
- Run: `vendor/bin/testo --suite=Integration`.

## CI/CD

### build.yml

- PHP matrix: `8.3`, `8.4`, `8.5`. `fail-fast: false`.
- Coverage job: PHP `8.4`, `pcov`, mutation testing.
- Prefer-lowest job: `composer update --prefer-lowest --prefer-stable`, then `composer build`.
- Backward compatibility job: `composer bc-check -- --from=<latest-tag>` when a tag exists.
  - **Latent risk:** the job only really runs once a previous tag exists.
    If `composer.json` carries no `bc-check`/`release-check` script and no
    `roave/backward-compatibility-check` dev dependency (plus the
    `ext-bcmath`/`ext-intl` platform pins), the initial release is green (no tag
    yet, so it skips) and the very next push to `master` fails with
    `Command "bc-check" is not defined`. Every package must carry the full set of
    scripts + roave + platform pins (see "composer.json: conventions").
  - **A major will not merge without this step.** `Backward compatibility` is a
    required status check with no `continue-on-error`, and roave exits with code 3
    on a deliberate major. The step in `templates/.github/workflows/build.yml`
    tolerates a non-zero report exactly when the topmost version heading in
    `CHANGELOG.md` declares a major above the latest tag. Consequence: the release
    PR must carry `## X.0.0 — date`, not `## Unreleased` — under `Unreleased` a
    breaking PR stays red, which is precisely the behaviour you want outside a
    release.
- Service containers only when they are needed (ClickHouse, Redis, etc.).
- Triggers: `pull_request` plus `push` to `master`.
- `concurrency` must cancel stale runs on the same branch.

### static-analysis.yml

- PHP `8.4`, `coverage: none`, `composer psalm` only.

### PHP extensions

List the minimal set: `json`, `mbstring`, `pdo_sqlite`, and so on.
If the package needs no special extensions, list `json`.

If the package uses property tests (`rasuvaeff/property-testing`), `mbstring` is
mandatory in every job (including `static-analysis.yml`). Without it a local
`composer build` is green (the `composer:2` image ships mbstring) while CI is red.

### Hardening (SHA-pinning)

The `templates/.github/workflows/*.yml` templates already ship hardened CI.
Every new package inherits that state; when creating a package you do **not**
need to touch the workflows, only replace `{{PHP_EXTENSIONS}}`.

| Rule | Details |
|---|---|
| `uses:` → SHA-pin | Every `uses:` references a 40-character commit SHA with a trailing `# vN` comment. Floating `@vN` tags are **forbidden** |
| Updates | Through Dependabot (`.github/dependabot.yml`, ecosystem `github-actions`). Dependabot can bump SHA-pinned lines and preserves the `# vN` comment |
| `permissions` | At workflow level: `permissions: { contents: read }`. Job-level is unnecessary when every job fits within `contents: read` |
| `persist-credentials` | `false` on every `actions/checkout` (protection against `artipacked`: credentials do not settle in `.git/config` and do not leak into artifacts) |
| Audit | `zizmor --persona=auditor .github/` must report no `unpinned-uses`, `excessive-permissions` or `artipacked`. Run it locally before a release whenever workflows change |

Getting the SHA for a new action (when one has to be added):

```bash
get_sha() {
  local repo="$1" tag="$2" t s
  read -r t s < <(gh api "repos/$repo/git/ref/tags/$tag" \
    --jq '[.object.type, .object.sha] | @tsv')
  [ "$t" = "tag" ] && gh api "repos/$repo/git/tags/$s" --jq '.object.sha' || echo "$s"
}
get_sha actions/checkout v4
```

Always dereference an annotated tag down to the commit (through
`git/tags/<sha>`), otherwise zizmor will not accept the pin as valid.

## Documentation

### README.md structure

**The README is bilingual: `README.md` (EN) plus `README.ru.md` (RU).** These are
two versions of one document — every change to README.md (a new section, API,
example, badge) goes into BOTH files in the same commit. A PR that touches only
one version is incomplete.

1. Title `# rasuvaeff/<name>`
2. Badges: Stable Version, Total Downloads, Build, Static analysis, Psalm level, License
3. Description (1-2 sentences)
4. LLM prompt: `> Using an AI coding assistant? [llms.txt](llms.txt) ...`
5. Requirements (PHP version, dependencies)
6. Installation (`composer require rasuvaeff/<name>`)
7. Usage (code examples, method tables)
8. Security (what is safe, what is not)
9. Examples (a link to `examples/`)
   Examples must be runnable, not merely illustrative.
10. Development (`composer build` and friends)
11. License (BSD-3-Clause)

### CHANGELOG.md

```markdown
# Changelog

## X.Y.Z — YYYY-MM-DD

- Description of change.
```

SemVer: breaking → major, feature → minor, fix → patch.

### llms.txt

Format: Markdown. Sections:
1. `# package-name`
2. Install (`composer require ...`)
3. Rules (the key constraints)
4. API reference with code examples (self-contained)

### examples/README.md

A table of scripts: Script | Shows | Needs server?
Instructions for running them with environment variables.

## Package AGENTS.md structure

Every package must carry its own `AGENTS.md`:

```markdown
# AGENTS.md — <package-name>

Guidance for AI agents working on this package. Read before changing code.

## What this is

<1-2 paragraphs: what the package does, its public API, its namespace>

## Golden rules

1. **Verification is mandatory.** Never claim "done" without a fresh green
   `composer build`. "Should work" does not count.
2. **No suppressions.** No `@psalm-suppress`, no baseline. Fix the root cause.
3. **Replace rule 3 before the first commit.** It must contain one
   package-specific safety/validation/contract rule.
4. **Preserve the public contract.** Update README + tests with any API change.

## Commands

No PHP/Composer on the host — run in Docker via the `composer:2` image.

```bash
docker run --rm -v "$PWD":/app -w /app composer:2 composer build
docker run --rm -v "$PWD":/app -w /app composer:2 composer cs:fix
docker run --rm -v "$PWD":/app -w /app composer:2 composer psalm
docker run --rm -v "$PWD":/app -w /app composer:2 composer test
docker run --rm -v "$PWD":/app -w /app composer:2 composer release-check
```

Or with Make:

```bash
make build
make cs-fix
make psalm
make test
make test-coverage
make mutation
make release-check
```

`make test-coverage` and `make mutation` bootstrap `pcov` inside the
`composer:2` container because the base image has no coverage driver.

## Invariants & gotchas

- <package-specific invariants>
- Code: `declare(strict_types=1)`, `final readonly class`, `#[\Override]`,
  explicit types.
- `examples/` is part of the public contract: keep scripts runnable and update
  `examples/README.md` when example usage changes.
- **CI workflows are SHA-pinned.** Every `uses:` in `.github/workflows/*.yml`
  references a 40-char commit SHA with a `# vN` trailing comment
  (e.g. `actions/checkout@<sha> # v4`). Never revert to floating `@vN` tags.
  Updates go through Dependabot, which bumps the SHA and preserves the comment.
  Workflows also carry `permissions: { contents: read }` at workflow level and
  `persist-credentials: false` on every `actions/checkout` step. Verify with
  `zizmor --persona=auditor .github/` — must report no `unpinned-uses`,
  `excessive-permissions`, or `artipacked` findings.

## When you finish

- Update `README.md` **and `README.ru.md`** (both languages, same commit;
  and `examples/` if usage changed); update `CHANGELOG.md` when releasing.
- Re-run `composer build`; if the change affects public API or release safety,
  also run `make release-check`. Paste the output.
```

## Security

| Rule | Details |
|---|---|
| Parameterized queries | Every user value is a bound parameter |
| Identifier validation | Regex whitelist: `/^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)?\z/` |
| Type token validation | `/^[A-Za-z0-9_(), ]+\z/` for `{name:Type}` placeholders |
| **Anchor with `\z`, not `$`** | Details and the incident: `docs/evolved-rules.md` ER-001 |
| Allow-list | Fields outside the list are dropped silently |
| Mandatory filters | `withMandatoryFilter()` for ACL/tenant, bypassing the allow-list |
| Raw SQL | Trusted context only; user values go through `$params` |
| Credentials | Through headers/variables, never in the URL |

## Naming

| Entity | Convention | Example |
|---|---|---|
| Package | `rasuvaeff/<kebab-case>` | `rasuvaeff/clickhouse-toolkit` |
| Namespace | `Rasuvaeff\<PascalCase>` | `Rasuvaeff\ClickHouseToolkit` |
| Class | PascalCase | `ComparisonSpecification` |
| Interface | PascalCase, no `I` prefix | `Specification` |
| File | Class name + `.php` | `Specification.php` |
| Method | camelCase | `whereEqual` |
| Fluent setter | `with*` | `withMandatoryFilter()` |
| Getter | `get*` / `is*` / `has*` | `getColumn()` |
| Static factory | semantic name | `equal()`, `create()`, `in()` |
| Private const | UPPER_SNAKE_CASE | `VALID_OPERATORS` |
| Test method | camelCase, descriptive | `throwsOnInvalidOperator` |
| Data provider | `<method>Provider` | `nullAllowedOperatorsProvider` |
| Exception message | English, no trailing period | `'Invalid operator "foo"'` |
| Integration test | `<Tech>IntegrationTest` | `SqliteIntegrationTest` |

## Batch operations: bin/dev

`bin/dev` is the tool for operating on several packages at once (manual:
`DEV-TOOL.md`; help: `bin/dev help`). Package selector: empty = all, a list
`a,b`, a glob `'yii3-outbox*'`, a family alias `@outbox` (full list:
`bin/dev aliases`).

| Command | Purpose |
|---|---|
| `bin/dev exec "<cmd>" [pkgs]` | A shell command in every package, in parallel |
| `bin/dev build` / `test` / `cs-fix` / `psalm` `[pkgs]` | Sugar for `exec "make <target>"` |
| `bin/dev git:status` / `branch` / `checkout` / `commit` / `push` / `pull` `[pkgs]` | Batch git; the mutating ones support `--dry-run` |
| `bin/dev replicate:check` / `files` / `copy-file` | Syncs `templates/` → packages per `replicate/manifest.bash` |
| `bin/dev changelog:add "<entry>" [--type=...] [pkgs]` | Writes into the `## Unreleased` section of several `CHANGELOG.md` files |

`bin/dev-self-test` must be green before committing any change to `bin/dev`.

For an LLM agent: `bin/dev` output grows in proportion to the number of packages
in the selector. At `--all`/`@family` scope, run it through a subagent (Agent
tool / Workflow) that returns a compact pass/fail table per package, rather than
reading every package's full log yourself.

## New package creation process

1. Create the directory: `mkdir -p <monorepo-root>/<name>`
2. Copy the templates from `templates/` and replace the placeholders.
3. Initialize git: `git init && git add -A && git commit -m "Initial skeleton"`
4. Create `src/` with the classes, following the style rules above.
5. Create `tests/` — one test per public class.
6. Run: `docker run --rm -v "$PWD":/app -w /app composer:2 composer install`
7. Run: `docker run --rm -v "$PWD":/app -w /app composer:2 composer cs:fix`
8. Run: `docker run --rm -v "$PWD":/app -w /app composer:2 composer build`
9. Fix everything until `composer build` is green.
10. Write README.md, llms.txt, AGENTS.md, examples/.
11. Create the GitHub repository and push.
12. Register on Packagist.
13. Push a SemVer tag.

## Process: create a package (create-php-package)

### Inputs

Ask the user for:
- Package name (kebab-case, for example `yii3-form-widgets`)
- A short description
- Runtime dependencies (for example `yiisoft/html`, `psr/log`)
- PHP extensions (for example `json` or `mbstring, pdo_sqlite`)

### Placeholders

| Placeholder | Value |
|---|---|
| `{{PACKAGE_KEBAB}}` | As given (for example `clickhouse-toolkit`) |
| `{{PACKAGE_PASCAL}}` | kebab → PascalCase: split on `-`, ucfirst each segment |
| `{{DESCRIPTION}}` | The description from the user |
| `{{PHP_EXTENSIONS}}` | The extensions from the user |

### Steps

1. Create the directory: `mkdir -p <monorepo-root>/<name>`
2. Copy the templates from `templates/` and replace the placeholders (see the "Required file set" table).
3. Create `src/`, `tests/`, `tests/Integration/`, `examples/`, `build/` (plus `.gitkeep`).
4. Add runtime dependencies to `composer.json` → `require`. Extra dev deps only for integration tests.
5. Write `README.md`, `llms.txt`, `AGENTS.md`, `CLAUDE.md` (`@AGENTS.md`), `examples/README.md` — from the `templates/` templates.
6. Write `src/` — follow every style rule above.
7. Write `tests/` — `<ClassName>Test.php` for every public class.
8. `git init && git add -A && git commit -m "Initial skeleton"`
9. `docker run --rm -v "$PWD":/app -w /app composer:2 composer install`
10. `docker run --rm -v "$PWD":/app -w /app composer:2 composer cs:fix`
11. `docker run --rm -v "$PWD":/app -w /app composer:2 composer build`
12. Keep fixing until `composer build` is green.

Or through the Makefile (copied from `templates/Makefile`):
```bash
make install && make cs-fix && make build
```

### Acceptance criteria

- `composer build` exits 0
- No `@psalm-suppress`
- Every public class carries `@api`
- Every test class carries `#[Covers]`
- The README documents the entire public API
- `examples/` are runnable and in sync with the README

---

## Process: build a package (build-php-package)

To run across several packages at once, use `bin/dev build [pkgs]` /
`bin/dev exec "<cmd>" [pkgs]` (see "Batch operations: bin/dev").

For a single package, use `bin/build-digest <pkg> <script>` (from the monorepo
root) instead of a bare `docker run`: the full output of
`composer build`/`test`/`psalm` (usually hundreds of lines) goes to
`<pkg>/build/digest-<script>.log`, and the terminal gets one `PASS`/`FAIL` line
(plus the last 30 log lines on failure). `bin/dev build`/`exec` already
parallelizes across packages — `build-digest` does not replace them, it saves an
LLM agent's context on single runs.

### Docker commands

Run these from the package root:

```bash
# The full gate
docker run --rm -v "$PWD":/app -w /app composer:2 composer build

# Individual tools
docker run --rm -v "$PWD":/app -w /app composer:2 composer cs:fix
docker run --rm -v "$PWD":/app -w /app composer:2 composer psalm
docker run --rm -v "$PWD":/app -w /app composer:2 composer test
docker run --rm -v "$PWD":/app -w /app composer:2 composer rector:fix
docker run --rm -v "$PWD":/app -w /app composer:2 composer release-check

# After changing composer.json
docker run --rm -v "$PWD":/app -w /app composer:2 sh -c \
  'git config --global --add safe.directory /app; composer update -q; composer normalize'

# Coverage + mutation through the Makefile: it installs and enables pcov temporarily
make test-coverage
make mutation
make release-check
```

`composer build` does NOT run mutation — that is a separate gate.
`make release-check` runs `composer release-check` and then mutation with `pcov`.

Or through the Makefile: `make build`, `make cs-fix`, `make psalm`, `make test`.

### Fixing errors

| Error | Action |
|---|---|
| `composer normalize` fails | `make normalize` |
| `cs` fails | `make cs-fix`, then re-run `cs` |
| `psalm` fails | Fix the root cause. **Never** add `@psalm-suppress`. If a global suppression is unavoidable, put it in `psalm.xml` under `<issueHandlers>` |
| `require-checker` fails | Add the missing dependency to `composer.json` |
| `testo` fails | Read the test output, fix the code |
| `rector` fails | `make rector-fix` |

### Integration tests

- **SQLite** (specification): in-memory, covered by `composer build` automatically.
- **ClickHouse** (clickhouse-toolkit): needs a running ClickHouse, skipped when `CLICKHOUSE_HOST` is unset.
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

### Golden rules

1. Never say "done" without a fresh green `composer build`. Paste the output.
2. No suppressions — fix the root cause.
3. `composer.lock` is gitignored, do not commit it.
4. `git ... dubious ownership` in the output is harmless noise.

---

## Process: review a package (review-php-package)

### Audit checklist

0. **Machine audit**: `bin/package-audit <pkg>` (from the root) or
   `make audit-package` (from the package). It deterministically checks: the
   required file set, `CLAUDE.md`→`@AGENTS.md`, the absence of
   `@psalm-suppress`/psalm baselines, `@api`/`@internal` on every type in `src/`,
   `#[Covers]`/`#[CoversNothing]` on test classes, that `@api` types are mentioned
   in `README.md`/`llms.txt`, lint plus execution of the server-independent
   `examples/*.php`, and the absence of stale `make x:y` references in the docs.
   `FAIL` is an error (non-zero exit), `WARN` is informational. After that, the
   manual steps below cover only what the script does not.
1. **Read the rules**: the root `AGENTS.md` plus the package `AGENTS.md`.
2. **Files**: check that every file from the "Required file set" table is present.
3. **Build**: `make build` must pass.
   For API changes and release candidates, also run `make release-check`.
4. **Code style**: scan every `src/*.php` and `tests/*.php`:
   - `declare(strict_types=1)` in every file
   - `final readonly class` or `final class` on every class
   - `@api` on every class in `src/` (`@internal` on utility ones)
   - `#[\Override]` on every implementation
   - Named arguments, explicit types, trailing comma
   - No `@psalm-suppress`
5. **composer.json**: name, license, php ^8.3, author, homepage, support, autoload, config, dev deps, scripts.
6. **Tests**: `#[Test]` on the class + `#[Covers]` + `yield` providers + `Assert::same(actual, expected)` + `#[BeforeTest]` for setUp.
7. **Documentation**: README (every section), CHANGELOG, llms.txt, AGENTS.md, CLAUDE.md, examples/.
   Check that `examples/` are not stale and reflect the current public API.
8. **Security** (when SQL is involved): parameterized queries, identifier validation, allow-list, mandatory filters.
9. **CI hardening**: `zizmor --persona=auditor .github/` — no `unpinned-uses`,
   `excessive-permissions`, `artipacked`. Every `uses:` SHA-pinned, with
   `permissions: { contents: read }` and `persist-credentials: false` on every
   checkout (see "CI/CD → Hardening (SHA-pinning)").

### Report format

```
## Review: rasuvaeff/<package-name>

### Status: PASS / FAIL

### Files: X/Y present (list the missing ones)
### Build: PASS / FAIL (output on failure)
### Code style: X issues — file:line — description
### composer.json: X issues
### Tests: X issues
### Documentation: X issues
### Security: X issues
### Summary: X critical, Y warnings
```

---

## Process: publish a package (publish-php-package)

### Pre-flight

```bash
make build  # from the package directory
make release-check  # for a pre-release / API changes
```

Check that:
- [ ] `composer build` is green
- [ ] `make release-check` is green for releases and API changes
- [ ] There is no `@psalm-suppress` (grep)
- [ ] Every public class carries `@api`
- [ ] Every test carries `#[Covers]`
- [ ] The README is up to date
- [ ] `examples/` are current and runnable
- [ ] The CHANGELOG has an entry for the version
- [ ] `homepage` + `support` are in composer.json
- [ ] `.gitattributes` carries `export-ignore`
- [ ] There are no `App\*` imports: `rg '^use App\\' src tests`

If any check fails, **stop and fix it**.

### SemVer

- **Major** (X.0.0): breaking API changes
- **Minor** (0.Y.0): new features, backwards-compatible
- **Patch** (0.0.Z): bug fixes, backwards-compatible

### Steps

**Push the tag and enable `master` protection ONLY after the first green CI run** —
otherwise a red first run (say, a PHP version the local `composer:2` 8.5 image
never exercises) on an already-protected master forces a delete-tag plus a
recovery PR.

1. Update `CHANGELOG.md` — set the release date.
2. `git add CHANGELOG.md && git commit -m "Release X.Y.Z"` (NO tag).
3. Create the GitHub repository (via `gh` or by hand) and push `master` (without the tag):
   ```bash
   gh repo create rasuvaeff/<name> --public --source=. --remote=origin --push
   # or
   git remote add origin git@github.com:rasuvaeff/<name>.git
   git push -u origin master
   ```
4. **Wait for green CI** (`gh run watch`). `master` is NOT protected yet — a red
   run is fixed directly on master (edit → commit → push → re-check), without a PR.
5. The tag goes on the green HEAD, once:
   ```bash
   git tag -a vX.Y.Z -m "X.Y.Z"
   git merge-base --is-ancestor vX.Y.Z origin/master && echo OK
   git push origin vX.Y.Z
   ```
6. Apply `master` protection (after green CI and the tag, once):
   ```bash
   gh api -X PUT "repos/rasuvaeff/<name>/branches/master/protection" \
     --input "${MONOREPO_ROOT}/templates/branch-protection.json"
   ```
7. Verify a clean clone: `bin/verify-clean-clone <name>` (from the root; add
   `--https` when the environment has no SSH key). It clones into a temporary
   directory, runs `composer install` + `build` through Docker, and cleans up
   after itself (including the root-owned `vendor/` the container leaves behind).
8. Register on Packagist: https://packagist.org → Submit → the repository URL.
9. Verify installation: `composer require rasuvaeff/<name> --dry-run`.

### Subsequent releases

`master` is protected (required PR + status checks), so a direct push is
rejected. The release commit goes through a PR, and the tag is pushed **onto the
merged commit**, once.

1. Update code + tests + README (feature branch → PR → CI → merge).
2. On the release branch, update `CHANGELOG.md`: `## Unreleased` → `## X.Y.Z — YYYY-MM-DD`.
3. `git commit -m "Release X.Y.Z"`.
4. PR → wait for green CI → merge (squash or rebase, either is fine).
5. `git checkout master && git pull --ff-only`.
6. `git tag -a vX.Y.Z -m "X.Y.Z"` **on the post-merge HEAD** (the commit from `origin/master`).
7. Verify the tag is reachable: `git merge-base --is-ancestor vX.Y.Z origin/master && echo OK`.
8. `git push origin vX.Y.Z` — **once, never move it**.
9. Packagist picks the tag up through the webhook (about a minute).

#### ⚠ Re-tagging is forbidden

Never delete or recreate a tag after it has been pushed to VCS. Packagist blocks
re-tagged versions permanently (`Upstream re-tag blocked`), and the only way out
is to release a new patch version. Therefore:

- the tag goes on **after** the merge, not before (squash/rebase create a new SHA);
- verify the tag is reachable from `origin/master` before pushing (step 7);
- a wrong SHA can be recreated locally before the push; after the push it cannot.

---

## Existing packages

The monorepo holds 55 published packages under the `rasuvaeff/*` vendor. Each
lives in its own directory whose name matches the package name, with the
namespace `Rasuvaeff\<PascalCase>` (kebab → PascalCase, see "Naming").

The current list is at https://github.com/rasuvaeff?tab=repositories and
https://packagist.org/packages/rasuvaeff/
