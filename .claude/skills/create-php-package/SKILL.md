---
name: create-php-package
description: Use when creating a new Composer package in this monorepo. Triggers on "create package", "new package", "scaffold package", "создай пакет". Reads AGENTS.md and templates/ in the project root, follows the full process: copy templates, replace placeholders, create src/ and tests/ skeleton, run composer install + build.
---

# Create PHP Package

Create a new `rasuvaeff/*` Composer package following the monorepo conventions.

## Before you start

1. Read `<monorepo-root>/AGENTS.md` for full rules.
2. Ask the user for:
   - Package name (kebab-case, e.g. `yii3-form-widgets`)
   - Short description
   - Runtime dependencies (e.g. `yiisoft/html`, `psr/log`)
   - PHP extensions needed (e.g. `json`, `mbstring, pdo_sqlite`)

## Placeholders

| Placeholder | Derivation |
|---|---|
| `{{PACKAGE_KEBAB}}` | Package name as-is (e.g. `clickhouse-toolkit`) |
| `{{PACKAGE_PASCAL}}` | kebab → PascalCase: split by `-`, ucfirst each segment (e.g. `ClickHouseToolkit`) |
| `{{DESCRIPTION}}` | User-provided description string |
| `{{PHP_EXTENSIONS}}` | User-provided extensions string (e.g. `json` or `mbstring, pdo_sqlite`) |

## Step-by-step process

### 1. Create directory

```bash
mkdir -p <monorepo-root>/<package-name>
```

### 2. Copy templates and replace placeholders

Copy these files from `templates/` and replace placeholders:

| Template | Destination |
|---|---|
| `templates/composer.json` | `composer.json` |
| `templates/.php-cs-fixer.php` | `.php-cs-fixer.php` |
| `templates/psalm.xml` | `psalm.xml` |
| `templates/infection.json5` | `infection.json5` |
| `templates/rector.php` | `rector.php` |
| `templates/.editorconfig` | `.editorconfig` |
| `templates/.gitignore` | `.gitignore` |
| `templates/.gitattributes` | `.gitattributes` |
| `templates/LICENSE.md` | `LICENSE.md` |
| `templates/CHANGELOG.md` | `CHANGELOG.md` |
| `templates/testo.php` | `testo.php` |
| `templates/.github/workflows/build.yml` | `.github/workflows/build.yml` |
| `templates/.github/workflows/static-analysis.yml` | `.github/workflows/static-analysis.yml` |

### 3. Create directories

```bash
mkdir -p src tests tests/Integration examples build
touch build/.gitkeep
```

### 4. Add runtime dependencies to composer.json

Edit `composer.json` to add user-specified runtime deps to `require` section.
Add extra dev-deps only if needed for integration tests (e.g. `yiisoft/db-sqlite`, `guzzlehttp/guzzle`).

If the package needs additional `allow-plugins` (e.g. `php-http/discovery`), add them.

### 5. Write package-specific files

Create from scratch (templates don't exist for these):

- `README.md` — follow the structure from AGENTS.md "Structure README.md" section
- `llms.txt` — compact API reference for LLMs
- `AGENTS.md` — follow the template from AGENTS.md "AGENTS.md package structure" section
- `CLAUDE.md` — single line: `@AGENTS.md`
- `examples/README.md` — table of example scripts

### 6. Write source code

Follow ALL code style rules from AGENTS.md:

- `declare(strict_types=1);` in every file
- `final readonly class` by default
- `@api` on public classes, `@internal` on utilities
- `#[\Override]` on interface implementations
- Named arguments, explicit types, trailing commas
- One class = one file
- Validation in constructors

#### Psalm annotations — write them now, not after psalm complains

`psalm.xml` runs at `errorLevel="1"`. Precise types are cheap while writing the
class and expensive to retrofit after release (narrowing a published signature
is a BC break). Never add `@psalm-suppress` and never create a baseline — fix
the root cause; if a global exception is truly unavoidable, it goes in
`psalm.xml` `<issueHandlers>`.

| Annotation | Where to use it |
|---|---|
| `non-empty-string` | Ids, keys, hashes, names, any string validated as non-empty in the constructor |
| `int<0, max>` / `positive-int` | Counts, limits, offsets, TTLs, sizes |
| `list<T>` | Every sequential array — never `array<int, T>` |
| `array{...}` shapes | `toArray()` and any fixed-key array |
| `@psalm-type` + `@psalm-import-type` | Declare a repeated array shape (DB row, JSON payload) once, import it in the classes and tests that consume it |
| `@implements` / `@extends` | `IteratorAggregate<int, T>`, `Traversable<K, V>`, generic parents |
| `@psalm-param array<string, mixed>` | Factories fed by untrusted input — accept `mixed` and narrow inside; never type untrusted input optimistically |
| `@template` | Only for genuinely generic types (visitors, collections, result wrappers) — invariant unless variance is proven necessary |

`@psalm-immutable` is optional and has no precedent in this monorepo: use it
only on leaf value objects with no service dependencies, and drop the
annotation if psalm demands a `@psalm-pure` cascade through third-party code —
do not silence the cascade.

Run `composer psalm` before `composer build` so type errors surface before the
full gate.

### 7. Write tests

For each public class, create `<ClassName>Test.php`:

- `#[Test]` on the class (every public `void`/`never` method becomes a test)
- `#[Covers(ClassName::class)]` on test class
- `#[DataProvider]` with `yield 'case name' => [...]`
- `Assert::same($actual, $expected)` for strict comparison — note the `(actual, expected)` order (reversed from PHPUnit)
- `#[BeforeTest]` for fixtures (any method name; lifecycle from `Testo\Lifecycle`)

### 8. Initialize git

```bash
cd <monorepo-root>/<package-name>
git init && git add -A && git commit -m "Initial skeleton"
```

### 9. Install dependencies

```bash
docker run --rm -v "$PWD":/app -w /app composer:2 composer install
```

### 10. Fix style and build

```bash
docker run --rm -v "$PWD":/app -w /app composer:2 composer cs:fix
docker run --rm -v "$PWD":/app -w /app composer:2 composer build
```

Fix all errors until `composer build` passes green.

### 11. Verify

- `composer build` exits 0
- No `@psalm-suppress` annotations
- All public classes have `@api`
- All test classes have `#[Covers]`
- README documents all public API

## After creation

Report to the user:
- Package directory path
- List of created files
- `composer build` output
- Next steps: create GitHub repo, register on Packagist, set SemVer tag (if asked)
