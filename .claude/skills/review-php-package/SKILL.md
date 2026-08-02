---
name: review-php-package
description: Use when reviewing or auditing a rasuvaeff/* Composer package for convention compliance. Triggers on "review package", "audit package", "check conventions", "проверь пакет", "ревью". Checks code style, test coverage, documentation, security, and AGENTS.md compliance.
---

# Review PHP Package

Audit a `rasuvaeff/*` package for compliance with monorepo conventions defined in AGENTS.md.

## Process

### 0. Run the deterministic audit first

```bash
bin/package-audit <package-directory>     # from the monorepo root
# or, from inside the package:
make audit-package
```

`bin/package-audit` mechanically covers, with no false-positive guessing:

| Check | Replaces manual step |
|---|---|
| Required files / `CLAUDE.md`→`@AGENTS.md` | 2 |
| No `@psalm-suppress`, no psalm baseline | 4 (suppress row) |
| Every `src/` type has `@api` or `@internal` | 4 (`@api` row) |
| Every test class has `#[Covers]`/`#[CoversNothing]` | 6 |
| Every `@api` type named in `README.md`/`llms.txt` (warn) | 7 |
| `examples/*.php` lint; server-independent ones run without fatal | 7 (examples) |
| No stale `make x:y` commands in docs | 7 (commands) |

`FAIL` ⇒ error (non-zero exit, gates CI); `WARN` ⇒ advisory. Server-dependent
examples are detected from the `Needs server?` column of `examples/README.md` and
are lint-only. The example **execution** check needs `vendor/` present — run
`make install` first, or the check degrades to lint-only with a `WARN`. The runner
mounts the monorepo root so path-repo siblings (core+backend pairs) resolve.

Take its findings as given, then do the manual steps below **only for what the
script cannot check** (code-style nuances, named arguments, security semantics,
composer.json fields, CI job shape).

### 1. Read the rules

Read `<monorepo-root>/AGENTS.md` and the package's own `AGENTS.md`.

### 2. Check required files

Verify every file from the "Required file set" table exists:

```
composer.json, src/, tests/, .php-cs-fixer.php, testo.php,
psalm.xml, infection.json5, rector.php, .editorconfig, .gitattributes,
.gitignore, README.md, CHANGELOG.md, LICENSE.md, llms.txt, AGENTS.md,
CLAUDE.md, .github/workflows/build.yml, .github/workflows/static-analysis.yml,
examples/README.md, build/.gitkeep
```

Report missing files.

### 3. Run build

```bash
cd <package-directory>
docker run --rm -v "$PWD":/app -w /app composer:2 composer build
```

Report pass/fail with output.

### 4. Check code style conventions

Scan all `src/*.php` and `tests/*.php` files for:

| Rule | Check |
|---|---|
| `declare(strict_types=1)` | Present in every file, after `<?php` + blank line |
| `final readonly class` or `final class` | Every class has `final` |
| `@api` on public classes | Every class in `src/` has `@api` or `@internal` |
| `#[\Override]` | On all method implementations |
| Named arguments | Call sites use `param: value` style |
| Explicit types | All params and returns typed |
| Trailing comma | In multiline arrays/arguments/parameters |
| Blank line before return/throw/try | Consistent |
| One class per file | No multiple classes in one file |
| Typed constants | `const array X = [...]` not `const X = [...]` |
| No `@psalm-suppress` | Grep for inline suppressions |

### 5. Check composer.json

- `name`: `rasuvaeff/<kebab-case>`
- `license`: `BSD-3-Clause`
- `php`: `^8.3`
- `authors`: Victor Razuvaev
- `homepage` + `support` URLs match package name
- PSR-4 autoload: `Rasuvaeff\<Pascal>\` → `src/`
- PSR-4 autoload-dev: `Rasuvaeff\<Pascal>\Tests\` → `tests/`
- `config.sort-packages`: `true`
- All standard dev-deps present
- Scripts: `build`, `cs`, `cs:fix`, `mutation`, `psalm`, `rector`, `test`, `test:coverage`, `test:coverage:ci`

### 6. Check tests

- Every public class in `src/` has a corresponding `<ClassName>Test.php`
- Every test class has `#[Covers]`
- Every test class has `#[Test]` (public `void`/`never` methods are tests)
- Data providers use `yield 'name' => [...]`
- Assertions use `Assert::same($actual, $expected)` (order `(actual, expected)`, reversed from PHPUnit)
- `#[BeforeTest]` for fixtures (lifecycle)
- Integration tests in `tests/Integration/` with env-based skip

### 7. Check documentation

- README has all required sections (header, badges, description, requirements, install, usage, security, examples, development, license)
- CHANGELOG has entries for released versions
- llms.txt has install, rules, API reference sections
- AGENTS.md has What this is, Golden rules, Commands, Invariants, When you finish sections
- CLAUDE.md contains `@AGENTS.md`
- examples/README.md has table of scripts

### 8. Check security

If package deals with SQL/databases:
- Parameterized queries for user values
- Identifier validation (regex whitelist)
- Allow-list for filter fields
- Mandatory filters for ACL/tenant
- Raw SQL only in trusted context

### 9. Check CI

- `build.yml`: PHP matrix 8.3/8.4/8.5, `fail-fast: false`, coverage job
- `static-analysis.yml`: PHP 8.4, psalm

## Output format

Produce a structured report:

```
## Review: rasuvaeff/<package-name>

### Status: PASS / FAIL

### Files: X/Y present (list missing)

### Build: PASS / FAIL (paste output if fail)

### Code style: X issues
- file:line — description

### composer.json: X issues
- description

### Tests: X issues
- description

### Documentation: X issues
- description

### Security: X issues
- description

### Summary
Total issues: X critical, Y warnings
```
