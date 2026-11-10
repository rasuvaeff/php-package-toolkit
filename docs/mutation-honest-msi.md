# Honest MSI: mutants outside `#[Covers]` (snapshot 2026-11-01)

A snapshot of what the mutation gate was hiding. Testo credits a test only with the code
named in its `#[Covers]`, and Infection by default mutates only credited code, so code the
tests execute but do not name produced **zero mutants** and `Not Covered: 0`. Running
`infection --with-uncovered` shows that code. Cause and rule: `AGENTS.md`
("Mutation testing: `--with-uncovered` is mandatory"), `docs/evolved-rules.md` ER-003,
`docs/mutation-blind-spots.md`.

## Summary

| Metric | Value |
|---|---|
| Packages with a result | 75 of 84 (run error: 8, skipped: 1) |
| Mutants with the flag | 42348 |
| Of them previously invisible (Not Covered) | 7874 (19%) |
| Median invisible share per package | 12% |
| Median MSI drop (covered → total) | 12 pp |
| Total MSI ≥ current `minMsi` | 4 of 75 |

Packages by invisible share:

| Share | Packages |
|---|---|
| under 5% | 9 |
| 5–15% | 37 |
| 15–30% | 16 |
| over 30% | 13 |

## Per package

Sorted by invisible share. "Visible MSI" is the Covered Code MSI, what the gate relied on
before; "Honest MSI" is the total MSI with `--with-uncovered`; "Margin" is the honest MSI
minus the package's current `minMsi` (negative: the gate would turn red under the new command).

| Package | Mutants | Not Covered | Share | Escaped | Visible MSI | Honest MSI | `minMsi` | Margin |
|---|---|---|---|---|---|---|---|---|
| `understudy-psalm` | 720 | 501 | 70% | 6 | 97% | 29% | 97 | -68 |
| `payments-testing` | 182 | 115 | 63% | 0 | 100% | 36% | 100 | -64 |
| `understudy-phpstan` | 571 | 356 | 62% | 5 | 97% | 36% | 97 | -61 |
| `json-ld` | 2726 | 1557 | 57% | 33 | 97% | 41% | 92 | -51 |
| `yii3-ab-testing-clickhouse` | 8 | 4 | 50% | 0 | 100% | 50% | 100 | -50 |
| `yii3-audit-log` | 80 | 37 | 46% | 0 | 100% | 53% | 100 | -47 |
| `bulkhead` | 237 | 90 | 38% | 9 | 93% | 58% | 89 | -31 |
| `circuit-breaker` | 532 | 196 | 37% | 56 | 83% | 52% | 96 | -44 |
| `yii3-metrics-prometheus` | 172 | 59 | 34% | 5 | 95% | 62% | 93 | -31 |
| `understudy-phpunit` | 50 | 17 | 34% | 0 | 100% | 66% | 95 | -29 |
| `yii3-filestorage-images` | 803 | 269 | 33% | 60 | 88% | 59% | 83 | -24 |
| `yii3-feature-flags` | 131 | 43 | 33% | 4 | 95% | 64% | 95 | -31 |
| `yii3-maintenance-mode` | 343 | 107 | 31% | 11 | 95% | 65% | 92 | -27 |
| `yii3-turnstile` | 75 | 17 | 23% | 1 | 98% | 76% | 98 | -22 |
| `payments` | 687 | 155 | 23% | 0 | 100% | 77% | 100 | -23 |
| `yii3-api-problem` | 90 | 18 | 20% | 0 | 100% | 80% | 100 | -20 |
| `retry` | 516 | 103 | 20% | 12 | 97% | 77% | 95 | -18 |
| `yii3-settings` | 123 | 23 | 19% | 1 | 99% | 80% | 99 | -19 |
| `yii3-mcp` | 2360 | 432 | 18% | 49 | 97% | 79% | 97 | -18 |
| `yii3-seo` | 940 | 171 | 18% | 1 | 99% | 81% | 99 | -18 |
| `yii3-filestorage-flysystem` | 274 | 47 | 17% | 25 | 88% | 73% | 88 | -15 |
| `schema` | 1209 | 205 | 17% | 72 | 92% | 77% | 85 | -8 |
| `yii3-health-check` | 73 | 12 | 16% | 0 | 100% | 83% | 100 | -17 |
| `understudy` | 4327 | 694 | 16% | 251 | 93% | 78% | 92 | -14 |
| `yii3-outbox` | 392 | 61 | 16% | 1 | 99% | 84% | 99 | -15 |
| `resilience` | 90 | 14 | 16% | 0 | 100% | 84% | 96 | -12 |
| `yii3-ab-testing-db` | 360 | 56 | 16% | 1 | 99% | 84% | 99 | -15 |
| `yii3-ab-testing-web` | 233 | 36 | 15% | 2 | 98% | 83% | 98 | -15 |
| `duration` | 137 | 21 | 15% | 2 | 98% | 81% | 93 | -12 |
| `context` | 314 | 47 | 15% | 20 | 92% | 78% | 90 | -12 |
| `quality-ledger` | 430 | 64 | 15% | 6 | 98% | 83% | 98 | -15 |
| `yii3-metrics` | 402 | 59 | 15% | 8 | 97% | 83% | 96 | -13 |
| `yii3-filestorage-attachments` | 124 | 18 | 15% | 6 | 94% | 80% | 94 | -14 |
| `media-converter` | 1633 | 236 | 14% | 48 | 96% | 82% | 95 | -13 |
| `yii3-telemetry` | 371 | 52 | 14% | 1 | 99% | 85% | 99 | -14 |
| `yii3-outbox-db` | 310 | 42 | 14% | 8 | 97% | 83% | 93 | -10 |
| `specification` | 699 | 93 | 13% | 46 | 92% | 80% | 85 | -5 |
| `yii3-centrifugo` | 381 | 45 | 12% | 14 | 95% | 84% | 85 | -1 |
| `yii3-idempotency` | 292 | 34 | 12% | 4 | 98% | 86% | 98 | -12 |
| `yii3-outbox-clickhouse` | 285 | 33 | 12% | 1 | 99% | 88% | 95 | -7 |
| `yii3-respect-validation` | 88 | 10 | 11% | 11 | 85% | 76% | 85 | -9 |
| `yii3-telemetry-otel` | 264 | 30 | 11% | 24 | 89% | 79% | 85 | -6 |
| `yii3-tenancy-db` | 44 | 5 | 11% | 3 | 92% | 81% | 89 | -8 |
| `yii3-clickhouse-toolkit` | 97 | 11 | 11% | 0 | 100% | 88% | 100 | -12 |
| `clickhouse-toolkit` | 1012 | 111 | 11% | 34 | 96% | 85% | 95 | -10 |
| `property-testing-core` | 4781 | 523 | 11% | 115 | 97% | 86% | 97 | -11 |
| `yii3-ab-testing` | 425 | 45 | 11% | 3 | 99% | 88% | 99 | -11 |
| `openapi-contract` | 3451 | 347 | 10% | 233 | 92% | 83% | 92 | -9 |
| `yii3-filestorage-db` | 605 | 60 | 10% | 58 | 89% | 80% | 89 | -9 |
| `yii3-utm` | 620 | 61 | 10% | 15 | 97% | 87% | 97 | -10 |
| `yii3-feature-flags-ui` | 314 | 30 | 10% | 10 | 96% | 87% | 94 | -7 |
| `yii3-feature-flags-db` | 86 | 8 | 9% | 3 | 96% | 87% | 95 | -8 |
| `yii3-utm-db` | 254 | 23 | 9% | 9 | 96% | 87% | 94 | -7 |
| `domain-monitor` | 1266 | 111 | 9% | 61 | 94% | 86% | 92 | -6 |
| `yii3-audit-log-db` | 35 | 3 | 9% | 1 | 96% | 88% | 96 | -8 |
| `rector-named-literals` | 71 | 6 | 8% | 0 | 100% | 91% | 100 | -9 |
| `yii3-filestorage` | 2228 | 188 | 8% | 262 | 87% | 79% | 87 | -8 |
| `yii3-idempotency-db` | 180 | 15 | 8% | 3 | 98% | 90% | 97 | -7 |
| `yii3-filestorage-web` | 328 | 27 | 8% | 17 | 94% | 86% | 93 | -7 |
| `yii3-settings-db` | 247 | 20 | 8% | 15 | 93% | 85% | 92 | -7 |
| `yii3-ab-testing-outbox` | 27 | 2 | 7% | 0 | 100% | 92% | 100 | -8 |
| `yii3-settings-ui` | 326 | 24 | 7% | 37 | 87% | 81% | 85 | -4 |
| `understudy-testo` | 28 | 2 | 7% | 0 | 100% | 92% | 95 | -3 |
| `context-http` | 152 | 10 | 7% | 10 | 92% | 86% | 85 | +1 |
| `yii3-correlation-id` | 128 | 8 | 6% | 0 | 100% | 93% | 100 | -7 |
| `rector-datetime-immutable` | 270 | 16 | 6% | 0 | 100% | 94% | 100 | -6 |
| `mutation-history` | 223 | 10 | 4% | 5 | 97% | 93% | 97 | -4 |
| `yii3-tenancy` | 106 | 4 | 4% | 11 | 89% | 85% | 88 | -3 |
| `context-process` | 27 | 1 | 4% | 1 | 96% | 92% | 95 | -3 |
| `yii3-outbox-webhooks-bridge` | 81 | 3 | 4% | 2 | 97% | 93% | 95 | -2 |
| `pinned-http-client` | 233 | 8 | 3% | 6 | 97% | 93% | 95 | -2 |
| `yii3-mcp-rbac-bridge` | 60 | 2 | 3% | 0 | 100% | 96% | 100 | -4 |
| `context-db` | 506 | 11 | 2% | 48 | 90% | 88% | 88 | +0 |
| `yii3-mcp-audit-log-bridge` | 27 | 0 | 0% | 2 | 92% | 92% | 90 | +2 |
| `yii3-mcp-telemetry-bridge` | 76 | 0 | 0% | 0 | 100% | 100% | 100 | +0 |

## Not measured

| Package | Reason |
|---|---|
| `link-preview` | Cause found by the pilot: the `composer-pcov:local` image lacks `ext-intl`, and the package needs `idn_to_ascii()`; 4 tests fail in the initial run, Infection exits with rc=1. Needs an image with intl |
| `context-cli` | Infection failed within seconds (rc=1); log not kept; probably the same missing extension in the image (as with `link-preview`), not verified |
| `property-testing-names` | Infection failed within seconds (rc=1); log not kept; probably the same missing extension in the image (as with `link-preview`), not verified |
| `property-testing-openapi` | Infection failed within seconds (rc=1); log not kept; probably the same missing extension in the image (as with `link-preview`), not verified |
| `property-testing-phpunit` | Infection failed within seconds (rc=1); log not kept; probably the same missing extension in the image (as with `link-preview`), not verified |
| `property-testing-testo` | Infection failed within seconds (rc=1); log not kept; probably the same missing extension in the image (as with `link-preview`), not verified |
| `result` | Infection failed within seconds (rc=1); log not kept; probably the same missing extension in the image (as with `link-preview`), not verified |
| `yii3-recaptcha` | Infection failed within seconds (rc=0); log not kept; probably the same missing extension in the image (as with `link-preview`), not verified |
| `doc-exec` | no infection.json5, vendor/ or tests/ in the working copy |

## How to read this, and what not to do

- This is one run of a local image with pcov. Numbers drift by a couple of points:
  `pinned-http-client` gave 95% and 93% on two consecutive runs because `SystemResolver`
  depends on the container's DNS. Do not make decisions on a 1–2 pp difference.
- The visible MSI was true for what it measured: mutants in credited code are killed.
  The fiction was the denominator.
- Part of Not Covered is cured by `#[Covers]` on tests that already execute the code
  (`json-ld` without the attributes: 2543 mutants give about 93%); part cannot be killed
  at all (mutants on signature lines, code in a separate process, environment dependence).
- The pilots (`json-ld`, `schema`, `pinned-http-client`, `link-preview`) do not update the
  numbers in the table: it is a snapshot taken before the fixes.
- Lazy rollout: touch a package, add the flag and bring its total MSI up to its `minMsi`,
  without lowering the threshold.
- There is no script in `bin/` that rebuilds this table: the `infection --with-uncovered`
  run across packages was a one-off.
