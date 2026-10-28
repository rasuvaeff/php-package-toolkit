# Package families

A map of what the workspace holds, for orientation before reading `AGENTS.md`
(the rulebook) or `docs/evolved-rules.md` (the incident catalogue). Ninety
published `rasuvaeff/*` packages (Packagist, 2026-10-28), mostly Yii3 ecosystem
integrations plus framework-agnostic primitives. Each directory is an
independent Composer package with its own git history, CI and Packagist entry —
a meta-repo, not a single project.

## Core + swappable backend

The pattern `AGENTS.md` § "Config plugin" exists for: the core binds only its
own facade, each backend binds the swappable interface. Core plus exactly one
backend works with no application config; two backends at once is a deliberate
error. An `@name` on the left is the `bin/dev` selector for that family (the
full list is `bin/dev aliases`); a family with no selector is spelled out.

```
@ab            yii3-ab-testing → -db | -clickhouse | -web | -outbox
@outbox        yii3-outbox → -db | -clickhouse | -webhooks-bridge (bridges to @webhooks)
@webhooks      yii3-webhooks → -db
@flags         yii3-feature-flags → -db | -ui
@settings      yii3-settings → -db | -ui
@audit         yii3-audit-log → -db (also consumed by yii3-mcp-audit-log-bridge)
@idempotency   yii3-idempotency → -db | -redis
@tenancy       yii3-tenancy → -db
@workflow      yii3-workflow → -db
@utm           yii3-utm → -db
@filestorage   yii3-filestorage → -db | -flysystem | -web | -attachments | -images
@mcp           yii3-mcp → -audit-log-bridge | -rbac-bridge | -telemetry-bridge
@telemetry     yii3-telemetry → -otel (consumed by yii3-mcp-telemetry-bridge)
@metrics       yii3-metrics → -prometheus | -otel
@clickhouse    clickhouse-toolkit (framework-agnostic) → yii3-clickhouse-toolkit
               (also a runtime dep of yii3-ab-testing-clickhouse, yii3-outbox-clickhouse)
payments       payments → payments-testing (the shipped test doubles)
```

## Framework-agnostic primitives

No Yii3 dependency, and the most reused runtime dependencies in the workspace:

One-liners below are each package's own `composer.json` description.

```
duration            type-safe immutable duration value object
retry               closure-first retry with backoff, jitter, PSR-18 support → duration
circuit-breaker     circuit breaker with in-memory, APCu and Redis backends → duration
bulkhead            cross-process concurrency limiter for PHP-FPM (Redis/APCu) → duration
resilience          composes retry, circuit breaker and bulkhead in the correct order
media-converter     type-safe wrapper over the ffmpeg/ffprobe subprocess → bulkhead, duration, retry
result              typed Result and Option primitives
specification       specification pattern over Yiisoft DB queries, with injection protection
context             deadline, cancellation and request-scoped values
                    → context-cli | context-db | context-http | context-process
schema              schema-as-code combinators: validation, generation, JSON Schema export
json-ld             JSON-LD 1.1 processor: expand, flatten, node API, RDF, N-Quads
link-preview        SSRF-safe PSR-18 fetching plus OpenGraph/Twitter/HTML metadata
pinned-http-client  PSR-18 client for untrusted URLs: resolves, checks and pins every address
domain-monitor      HTTP, SSL, WHOIS, DNS, ports, security headers, robots.txt, sitemaps
```

## Standalone Yii3 integrations

```
yii3-recaptcha, yii3-turnstile, yii3-centrifugo, yii3-respect-validation,
yii3-health-check, yii3-maintenance-mode, yii3-seo, yii3-api-problem
yii3-correlation-id → yii3-api-problem
```

## Testing and tooling

Not runtime dependencies of an application, but `require-dev` in nearly every
package above:

```
@property-testing  property-testing-core — framework-agnostic property-based testing
                   engine: generators, shrinking, runner, regression corpus, events
                   → -testo | -phpunit | -names | -openapi
                   (property-testing 2.x is frozen and abandoned in favour of -testo)
@understudy        understudy — test double library with a call-closure API
                   → -testo | -phpunit | -psalm | -phpstan
openapi-contract   framework-neutral OpenAPI contract validation for PSR-7 exchanges
doc-exec           doctest: executes fenced code blocks from the docs and diffs the output
quality-ledger     append-only history of quality signals, cross-run diff, ratchet gating
mutation-history   the same, over Infection logs — the ratchet behind `minMsi`
@rector            rector-named-literals, rector-datetime-immutable
```

## How to work here

| Task | Entry point |
|---|---|
| Create a package | the `create-php-package` skill |
| Build/test one | the `build-php-package` skill, or `bin/build-digest <pkg> build` |
| Review one against the conventions | the `review-php-package` skill; the machine-checkable part is `bin/package-audit <pkg>` |
| Raise mutation coverage | the `mutation-php-package` skill |
| Publish/release | the `publish-php-package` skill; the post-publish check is `bin/verify-clean-clone <pkg>` |
| Check what a consumer actually downloads | `bin/dist-smoke <pkg>` |
| Find types no mutant covers | `bin/covers_audit.py` + `bin/covers_report.py` → `docs/mutation-blind-spots.md` |
| Operate on many packages at once | `bin/dev` (`bin/dev help`, `bin/dev aliases`) |
| Merge a family's `config-plugin` the way an app does | `bin/config-merge-harness @family` |
