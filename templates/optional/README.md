# templates/optional

Files a package takes **when it needs them**, unlike `templates/*`, which every
package carries. Each one is either a reference to adapt or a snippet to append,
never a verbatim copy into a fresh skeleton.

| Path | When | What to change |
|---|---|---|
| `SKILL.md` | Always, in practice — 41 of the published packages ship one | Copy to `resources/skills/rasuvaeff-<kebab>/SKILL.md`, replace the placeholders, and add `extra.skills.source` to `composer.json` (see AGENTS.md § "extra: the shipped agent skill"). `.gitattributes` must not export-ignore `resources/` |
| `tests/Support/ExampleGenerators.php.example` | The package has property tests whose generators outgrew one call | Namespace, class name, the generators themselves. The docblock is the rule it exists for — a generator helper inside the test class turns rector red on `release-check` |
| `tests/Integration/CrossDatabaseMigrationTest.php.example` | A `*-db` package with a migration | Namespace, migration class names, table name, storage class, the `<PKG>_TEST_DB` variable. Mandatory for a package with a migration: ER-049 |
| `.github/workflows/database-integration-job.yml` | Same package | `{{PACKAGE_SNAKE}}`, `{{PACKAGE_UPPER}}`. Append to the package's `build.yml` under `jobs:`; do not gate it on the `changes` filter |
| `docs-site/docs.yml` | A family publishes one documentation site out of the core repository | Everything package-specific: this is the understudy family's workflow, kept because the shape is the point — API reference reflected from several `src/` trees, PRs build but never deploy, and `composer outdated` on the documentation lock turns a site documenting a three-minors-old version red instead of quiet |
| `docs-site/docs-links.yml` | The site has external links | Paths. Deliberately a separate workflow: its verdict depends on somebody else's host being up, so a dead link must not block a deploy |
| `docs-site/.vale.ini` | The site is prose somebody reads | `Vocab`, and the exclusion list — every `= NO` there is a decision against a Microsoft-style rule, not a way to make the run green |

The doc-site files assume a `docs/` tree (`docs/src/**`, `docs/scripts/check-links.mjs`,
`docs/package-lock.json`) that lives in the package repository; this directory
carries the CI, not the site generator.
