# manifest.bash — what bin/dev replicate:* propagates from templates/.
#
# Byte-for-byte copies: templates/<file> → <pkg>/<file>.
#
# The first workspace-wide audit (2026-07-11, 48/50 packages "drifted")
# showed that most drift is LEGITIMATE per-package variation, not aging.
# Evicted from the manifest, with reasons:
#
#   .php-cs-fixer.php  Finder dir list is per-package (benchmarks/,
#                      migrations/ exist only in some packages)
#   rector.php         9 packages carry deliberate withSkip blocks with
#                      load-bearing comments (reflection-driven tests,
#                      psalm level 1 interplay)
#   Makefile           bench/integration targets are per-package; template
#                      itself lags the majority (no bench target)
#   testo.php          per-package Integration suites and FinderConfig
#   .gitattributes     per-package export-ignore lines (benchmarks,
#                      ROADMAP.md, sonar-project.properties)
#   .gitignore         load-bearing extras (yii3-mcp-dev-tools
#                      /config/.merge-plan.php); build/.gitkeep pattern
#                      contested between template and packages
#   LICENSE.md         copyright year is package-specific (first release:
#                      2024 for clickhouse-toolkit and specification)
#   psalm.xml          per-package issueHandlers allowed by AGENTS.md
#   infection.json5    minMsi matures per package
#
# A file belongs here only when it is BOTH intended identical everywhere
# AND the template is its canonical source.
REPLICATE_FILES=(
  .editorconfig
  .github/ISSUE_TEMPLATE/bug_report.yml
  .github/ISSUE_TEMPLATE/feature_request.yml
  .github/ISSUE_TEMPLATE/config.yml
  .github/workflows/zizmor.yml
)
