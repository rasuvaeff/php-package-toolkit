#!/usr/bin/env python3
"""Turn covers-audit.json into a triaged markdown report."""
import json
import os
import re
import sys
from datetime import date
from pathlib import Path

# The workspace root: the directory whose direct children are the package
# repositories. Defaults to the parent of bin/, overridable for a workspace
# laid out elsewhere.
ROOT = Path(os.environ.get('MONOREPO_ROOT') or Path(__file__).resolve().parent.parent)
AUDIT = Path(sys.argv[1])
OUT = Path(sys.argv[2])

sys.path.insert(0, str(Path(__file__).resolve().parent))
from covers_audit import has_logic  # noqa: E402


def classify(pkg, rel, kind):
    return 'real' if has_logic(ROOT / pkg / rel, kind) else 'trivial'


rows = []
for e in json.load(AUDIT.open()):
    for b in e['blind']:
        rows.append({
            'package': e['package'],
            'file': b['file'],
            'kind': b['kind'],
            'severity': classify(e['package'], b['file'], b['kind']),
            'integration_only': bool(b['mentioned_in_coversnothing']),
            'tests': b['mentioned_in_coversnothing'],
        })

real = [r for r in rows if r['severity'] == 'real']
trivial = [r for r in rows if r['severity'] == 'trivial']
by_pkg = {}
for r in real:
    by_pkg.setdefault(r['package'], []).append(r)

lines = [
    '# Mutation blind spots: src/ types never named in a `#[Covers(...)]`',
    '',
    'Testo builds its coverage XML from `#[Covers]` attribution rather than from',
    'pcov line execution, and Infection generates mutants only for lines that',
    'report as covered. A `src/` type named in no `#[Covers]` anywhere therefore',
    'produces **zero mutants** — the package\'s mutation gate says nothing about it,',
    'no matter how thoroughly the test suite exercises it at runtime.',
    '',
    f'Snapshot of {date.today().isoformat()}. Published packages only (the frozen `property-testing` excluded): '
    f'anything but `"type": "project"`, with an `origin` remote — an application has no mutation '
    f'gate to lie about, and an unreleased checkout has no consumer to mislead. '
    f'Regenerate with:',
    '',
    '```bash',
    'bin/covers_audit.py build/covers-audit.json',
    'bin/covers_report.py build/covers-audit.json docs/mutation-blind-spots.md',
    '```',
    '',
    f'- types scanned: **{sum(1 for _ in rows)}** flagged out of all `src/` types',
    f'- with real mutable logic: **{len(real)}** across **{len(by_pkg)}** packages',
    f'- trivial (interfaces and types with no mutable construct: DTOs, logic-free exceptions and enums): {len(trivial)} — no mutants would exist anyway',
    f'- of the {len(real)} real ones, **{sum(1 for r in real if r["integration_only"])}** are exercised only by a `#[CoversNothing]` integration test',
    '- still true on `testo/codecov` 0.2.5: its changelog keeps lines outside `#[Covers]` in the coverage report as uncovered, but Infection',
    '  still generates no mutants for them. Measured on `retry`: pointing two tests',
    '  at another class dropped 413 to 408 mutants with `Not Covered: 0`.',
    '- a type exercised only in a subprocess (`understudy-phpstan` runs PHPStan via',
    '  `exec()`) is invisible to pcov too, so a `#[Covers]` cannot fix it: it needs an',
    '  in-process test.',
    '- the "logic" filter is a regex over the source, an upper bound: confirm a package',
    '  by adding `#[Covers]` and comparing the mutant count before and after.',
    '',
    '## Types with real logic and zero mutants',
    '',
    '| Package | Type | Kind | Only reached via `#[CoversNothing]` test |',
    '|---|---|---|---|',
]
for pkg in sorted(by_pkg, key=lambda p: (-len(by_pkg[p]), p)):
    for r in sorted(by_pkg[pkg], key=lambda r: r['file']):
        mark = '**yes** — ' + ', '.join(Path(t).name for t in r['tests']) if r['integration_only'] else 'no'
        lines.append(f"| `{pkg}` | `{r['file']}` | {r['kind']} | {mark} |")

lines += ['', '## Trivial — listed for completeness', '',
          '| Package | Type | Kind |', '|---|---|---|']
for r in sorted(trivial, key=lambda r: (r['package'], r['file'])):
    lines.append(f"| `{r['package']}` | `{r['file']}` | {r['kind']} |")

OUT.write_text('\n'.join(lines) + '\n')
print(f'real: {len(real)} in {len(by_pkg)} packages; trivial: {len(trivial)}')
print()
print(f"{'package':<32} {'real':>5} {'integration-only':>17}")
for pkg in sorted(by_pkg, key=lambda p: (-len(by_pkg[p]), p)):
    rs = by_pkg[pkg]
    print(f"{pkg:<32} {len(rs):>5} {sum(1 for r in rs if r['integration_only']):>17}")
