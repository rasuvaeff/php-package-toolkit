# Mutation blind spots: src/ types never named in a `#[Covers(...)]`

Testo builds its coverage XML from `#[Covers]` attribution rather than from
pcov line execution, and Infection generates mutants only for lines that
report as covered. A `src/` type named in no `#[Covers]` anywhere therefore
produces **zero mutants** — the package's mutation gate says nothing about it,
no matter how thoroughly the test suite exercises it at runtime.

Snapshot of 2026-11-10. Published packages only (the frozen `property-testing` excluded): anything but `"type": "project"`, with an `origin` remote — an application has no mutation gate to lie about, and an unreleased checkout has no consumer to mislead. Regenerate with:

```bash
bin/covers_audit.py build/covers-audit.json
bin/covers_report.py build/covers-audit.json docs/mutation-blind-spots.md
```

- types scanned: **107** flagged out of all `src/` types
- with real mutable logic: **18** across **6** packages
- trivial (interfaces and types with no mutable construct: DTOs, logic-free exceptions and enums): 89 — no mutants would exist anyway
- of the 18 real ones, **1** are exercised only by a `#[CoversNothing]` integration test
- still true on `testo/codecov` 0.2.5: its changelog keeps lines outside `#[Covers]` in the coverage report as uncovered, but Infection
  still generates no mutants for them. Measured on `retry`: pointing two tests
  at another class dropped 413 to 408 mutants with `Not Covered: 0`.
- a type exercised only in a subprocess (`understudy-phpstan` runs PHPStan via
  `exec()`) is invisible to pcov too, so a `#[Covers]` cannot fix it: it needs an
  in-process test.
- the "logic" filter is a regex over the source, an upper bound: confirm a package
  by adding `#[Covers]` and comparing the mutant count before and after.

## Types with real logic and zero mutants

| Package | Type | Kind | Only reached via `#[CoversNothing]` test |
|---|---|---|---|
| `understudy-psalm` | `src/Psalm/BuilderReturnType.php` | class | no |
| `understudy-psalm` | `src/Psalm/CaptorRecorder.php` | class | no |
| `understudy-psalm` | `src/Psalm/Internal/BuilderType.php` | class | no |
| `understudy-psalm` | `src/Psalm/Internal/WireShape.php` | class | no |
| `understudy-psalm` | `src/Psalm/MatcherArgument.php` | class | no |
| `understudy-psalm` | `src/Psalm/SpecificationRules.php` | class | no |
| `understudy-psalm` | `src/Psalm/SpecificationScope.php` | class | no |
| `understudy-psalm` | `src/Psalm/StaticBuilderReturnType.php` | class | no |
| `property-testing-phpunit` | `src/PhpUnit/PhpUnitTrialExecutor.php` | class | no |
| `property-testing-phpunit` | `src/PhpUnit/PropertyCheck.php` | class | no |
| `property-testing-phpunit` | `src/PhpUnit/PropertyTesting.php` | trait | no |
| `property-testing-phpunit` | `src/PhpUnit/VerboseListener.php` | class | no |
| `schema` | `src/Psalm/ObjectShapeProvider.php` | class | no |
| `schema` | `src/Psalm/Plugin.php` | class | no |
| `yii3-idempotency-redis` | `src/ClaimTokens.php` | class | no |
| `yii3-idempotency-redis` | `src/Redis/LuaScripts.php` | class | no |
| `property-testing-core` | `src/Runner/Redis/PhpRedisCorpusClient.php` | class | **yes** — RedisIntegrationTest.php |
| `rector-datetime-immutable` | `src/Internal/MutableDateTimeBoundaryAnalyzer.php` | class | no |

## Trivial — listed for completeness

| Package | Type | Kind |
|---|---|---|
| `context` | `src/ContextException.php` | class |
| `context` | `src/HrTimeSource.php` | class |
| `context-db` | `src/Dialect.php` | enum |
| `json-ld` | `src/Exception/CanonicalizationLimitException.php` | class |
| `json-ld` | `src/Exception/ContextRecursionException.php` | class |
| `json-ld` | `src/Exception/DocumentLoadingException.php` | class |
| `json-ld` | `src/Exception/ErrorCode.php` | enum |
| `json-ld` | `src/Exception/InvalidContextException.php` | class |
| `json-ld` | `src/Exception/InvalidInputException.php` | class |
| `json-ld` | `src/Exception/InvalidJsonException.php` | class |
| `json-ld` | `src/Exception/InvalidNQuadsException.php` | class |
| `json-ld` | `src/RdfDirection.php` | enum |
| `link-preview` | `src/Adapter/AdapterFailure.php` | enum |
| `link-preview` | `src/Extract/ExtractFailure.php` | enum |
| `link-preview` | `src/Extract/JsonLdFailure.php` | enum |
| `link-preview` | `src/Fetch/FetchFailureReason.php` | enum |
| `link-preview` | `src/Fetch/UrlRejection.php` | enum |
| `media-converter` | `src/Internal/OutputMode.php` | enum |
| `media-converter` | `src/Operation/Position.php` | enum |
| `payments` | `src/ForbiddenException.php` | class |
| `payments` | `src/Internal/Types.php` | class |
| `payments` | `src/Internal/WebhookLimits.php` | class |
| `payments` | `src/MalformedResponseException.php` | class |
| `payments` | `src/NotFoundException.php` | class |
| `payments` | `src/ProviderDeclinedException.php` | class |
| `payments` | `src/RateLimitedException.php` | class |
| `payments` | `src/RefundFailedException.php` | class |
| `payments` | `src/ServerException.php` | class |
| `payments` | `src/TransportException.php` | class |
| `payments` | `src/UnauthorizedException.php` | class |
| `payments-testing` | `src/Internal/Types.php` | class |
| `pinned-http-client` | `src/Refusal.php` | enum |
| `property-testing-core` | `src/Event/TargetImproved.php` | class |
| `property-testing-core` | `src/Internal/ReplayVerdict.php` | enum |
| `property-testing-core` | `src/Runner/TargetOutcome.php` | class |
| `property-testing-core` | `src/StateMachine/Invariant.php` | class |
| `property-testing-core` | `src/StateMachine/Precondition.php` | class |
| `property-testing-core` | `src/StateMachine/Rule.php` | class |
| `quality-ledger` | `src/DiffEntry.php` | class |
| `quality-ledger` | `src/GateResult.php` | class |
| `quality-ledger` | `src/Internal/AbsentStatus.php` | class |
| `quality-ledger` | `src/Internal/RunRecord.php` | class |
| `quality-ledger` | `src/Internal/Transition.php` | class |
| `quality-ledger` | `src/StillBadEntry.php` | class |
| `quality-ledger` | `src/TrendPoint.php` | class |
| `resilience` | `src/PipelineOrder.php` | enum |
| `retry` | `src/Jitter/JitterMode.php` | enum |
| `specification` | `src/LikeMatch.php` | enum |
| `understudy` | `src/Runtime/ReferenceSlot.php` | class |
| `understudy` | `src/Runtime/SequenceVerdict.php` | enum |
| `understudy-psalm` | `src/Psalm/Issue/UnderstudyMisuse.php` | class |
| `yii3-ab-testing-db` | `src/Exception/ExperimentAlreadyExistsException.php` | class |
| `yii3-ab-testing-db` | `src/Exception/ExperimentNotFoundException.php` | class |
| `yii3-ab-testing-db` | `src/Exception/InvalidExperimentRowException.php` | class |
| `yii3-ab-testing-outbox` | `src/AbTestingOutboxEventType.php` | enum |
| `yii3-ab-testing-web` | `src/AnonymousToAuthenticatedStrategy.php` | enum |
| `yii3-ab-testing-web` | `src/SubjectIdSource.php` | enum |
| `yii3-centrifugo` | `src/CentrifugoException.php` | class |
| `yii3-centrifugo` | `src/Doctor/CheckCategory.php` | enum |
| `yii3-centrifugo` | `src/Doctor/CheckStatus.php` | enum |
| `yii3-filestorage` | `src/Exception/AddException.php` | class |
| `yii3-filestorage` | `src/Exception/BlobBusyException.php` | class |
| `yii3-filestorage` | `src/Exception/ContentTooLargeException.php` | class |
| `yii3-filestorage` | `src/Exception/InvalidConfigException.php` | class |
| `yii3-filestorage` | `src/Exception/LedgerException.php` | class |
| `yii3-filestorage` | `src/Exception/PolicyViolationException.php` | class |
| `yii3-filestorage` | `src/Exception/RemoveException.php` | class |
| `yii3-filestorage` | `src/Exception/StoreException.php` | class |
| `yii3-filestorage` | `src/Exception/UnresolvableVariantException.php` | class |
| `yii3-filestorage` | `src/Exception/UnsupportedMediaTypeException.php` | class |
| `yii3-filestorage` | `src/Exception/UploadFailedException.php` | class |
| `yii3-filestorage` | `src/Exception/UploadSizeException.php` | class |
| `yii3-filestorage` | `src/Exception/UploadTooLargeException.php` | class |
| `yii3-filestorage-db` | `src/Command/Outcome.php` | enum |
| `yii3-filestorage-db` | `src/Exception/InvalidFileRowException.php` | class |
| `yii3-filestorage-images` | `src/Exception/DerivativeGenerationException.php` | class |
| `yii3-filestorage-images` | `src/Exception/InvalidPresetException.php` | class |
| `yii3-filestorage-images` | `src/Exception/ProcessingFailedException.php` | class |
| `yii3-filestorage-images` | `src/Exception/SvgSanitizationException.php` | class |
| `yii3-filestorage-images` | `src/Exception/UnknownPresetException.php` | class |
| `yii3-filestorage-images` | `src/Exception/UnsupportedSourceException.php` | class |
| `yii3-filestorage-images` | `src/Fit.php` | enum |
| `yii3-health-check` | `src/HealthStatus.php` | enum |
| `yii3-idempotency` | `src/FailureKind.php` | enum |
| `yii3-idempotency` | `src/MissingKeyException.php` | class |
| `yii3-idempotency-redis` | `src/UnexpectedRedisReplyException.php` | class |
| `yii3-mcp` | `src/OpenApi/PlannedOperationRequest.php` | class |
| `yii3-outbox-db` | `src/Exception/OutboxWriteOutsideTransactionException.php` | class |
| `yii3-webhooks` | `src/WebhookDeliveryStatus.php` | enum |
