#!/usr/bin/env python3
"""Audit: which src/ classes are never named in a #[Covers(...)] attribute.

Testo builds its coverage XML from #[Covers] attribution, not from pcov line
execution, and Infection generates mutants only for lines that report as
covered. A src class named in no #[Covers] therefore gets ZERO mutants — the
mutation gate says nothing about it, however thoroughly it is exercised.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# The workspace root: the directory whose direct children are the package
# repositories. Defaults to the parent of bin/, overridable for a workspace
# laid out elsewhere.
ROOT = Path(os.environ.get('MONOREPO_ROOT') or Path(__file__).resolve().parent.parent)

TYPE_RE = re.compile(
    r'^\s*(?:(?:final|abstract|readonly)\s+)*(class|interface|enum|trait)\s+(\w+)',
    re.M)
NS_RE = re.compile(r'^\s*namespace\s+([^;]+);', re.M)
USE_RE = re.compile(r'^\s*use\s+([\\\w]+)(?:\s+as\s+(\w+))?\s*;', re.M)
COVERS_RE = re.compile(r'#\[\s*(?:\\?[\w\\]*\\)?Covers\s*\(\s*([\\\w]+)::class')
COVERSNOTHING_RE = re.compile(r'#\[\s*(?:\\?[\w\\]*\\)?CoversNothing')
# a method body is what Infection can mutate; interfaces never have one
BODY_RE = re.compile(r'function\s+\w+\s*\([^)]*\)[^;{]*\{')


def php_files(d):
    return sorted(d.rglob('*.php')) if d.is_dir() else []


def src_types(pkg):
    """[(fqcn, short, kind, has_body, relpath)] for every type declared in src/."""
    out = []
    for f in php_files(pkg / 'src'):
        text = f.read_text(errors='replace')
        ns = NS_RE.search(text)
        ns = ns.group(1).strip() if ns else ''
        for kind, name in TYPE_RE.findall(text):
            out.append((
                f'{ns}\\{name}' if ns else name,
                name,
                kind,
                bool(BODY_RE.search(text)),
                str(f.relative_to(pkg)),
            ))
    return out


def covered_names(pkg):
    """(fqcns, shorts, [(testfile, kind)]) declared via #[Covers]/#[CoversNothing]."""
    fq, short, tests = set(), set(), []
    for f in php_files(pkg / 'tests'):
        text = f.read_text(errors='replace')
        aliases = {}
        for full, alias in USE_RE.findall(text):
            full = full.lstrip('\\')
            aliases[alias or full.rsplit('\\', 1)[-1]] = full
        hits = COVERS_RE.findall(text)
        for ref in hits:
            ref = ref.lstrip('\\')
            if '\\' in ref:
                fq.add(ref)
                short.add(ref.rsplit('\\', 1)[-1])
            else:
                short.add(ref)
                if ref in aliases:
                    fq.add(aliases[ref])
        nothing = bool(COVERSNOTHING_RE.search(text))
        if hits or nothing:
            tests.append((str(f.relative_to(pkg)),
                          'CoversNothing' if nothing and not hits else 'Covers'))
    return fq, short, tests


def main():
    report = []
    for pkg in sorted(p for p in ROOT.iterdir() if (p / 'composer.json').is_file()):
        if not (pkg / 'src').is_dir() or not (pkg / 'tests').is_dir():
            continue
        # Libraries only. An application in the workspace (a sandbox, an example
        # app) has no mutation gate for a blind spot to lie about, and its class
        # count would drown the libraries in the report.
        try:
            manifest = json.loads((pkg / 'composer.json').read_text())
        except ValueError:
            continue
        if manifest.get('type', 'library') != 'library':
            continue
        # Published packages only. A local-only checkout (an unreleased
        # adapter, a spike) has no consumer to mislead, and naming it in a
        # public report announces work that was never released.
        if subprocess.run(['git', '-C', str(pkg), 'remote', 'get-url', 'origin'],
                          capture_output=True).returncode != 0:
            continue
        types = src_types(pkg)
        if not types:
            continue
        fq, short, tests = covered_names(pkg)
        nothing_files = [t for t, k in tests if k == 'CoversNothing']

        blind = []
        for fqcn, name, kind, has_body, rel in types:
            if fqcn in fq or name in short:
                continue
            if kind == 'interface' and not has_body:
                continue  # nothing for Infection to mutate
            # which CoversNothing test, if any, mentions this type by name
            seen_in = [t for t in nothing_files
                       if re.search(rf'\b{re.escape(name)}\b',
                                    (pkg / t).read_text(errors='replace'))]
            blind.append({'fqcn': fqcn, 'kind': kind, 'file': rel,
                          'mentioned_in_coversnothing': seen_in})

        report.append({
            'package': pkg.name,
            'src_types': len(types),
            'blind': blind,
            'coversnothing_files': nothing_files,
        })

    Path(sys.argv[1]).write_text(json.dumps(report, indent=1, ensure_ascii=False))

    tot_blind = sum(len(r['blind']) for r in report)
    tot_types = sum(r['src_types'] for r in report)
    hot = [r for r in report if r['blind']]
    print(f'packages audited      : {len(report)}')
    print(f'src types total       : {tot_types}')
    print(f'never named in #[Covers]: {tot_blind}   in {len(hot)} package(s)')
    print()
    print(f"{'package':<32} {'types':>5} {'blind':>5}  {'of which touched by a CoversNothing test':>5}")
    for r in sorted(hot, key=lambda r: -len(r['blind'])):
        touched = sum(1 for b in r['blind'] if b['mentioned_in_coversnothing'])
        print(f"{r['package']:<32} {r['src_types']:>5} {len(r['blind']):>5}  {touched:>5}")


if __name__ == '__main__':
    main()
