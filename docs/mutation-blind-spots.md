# Mutation blind spots: src/ types never named in a `#[Covers(...)]`

Testo builds its coverage XML from `#[Covers]` attribution rather than from
pcov line execution, and Infection generates mutants only for lines that
report as covered. A `src/` type named in no `#[Covers]` anywhere therefore
produces **zero mutants** — the package's mutation gate says nothing about it,
no matter how thoroughly the test suite exercises it at runtime.

Snapshot of 2026-10-28. Published library packages only: `"type": "library"` with an `origin` remote — an application has no mutation gate to lie about, and an unreleased checkout has no consumer to mislead. Regenerate with:

```bash
bin/covers_audit.py build/covers-audit.json
bin/covers_report.py build/covers-audit.json docs/mutation-blind-spots.md
```

- types scanned: **180** flagged out of all `src/` types
- with real mutable logic: **154** across **27** packages
- trivial (pure enums, logic-free exceptions, interfaces): 26 — no mutants would exist anyway
- of the 154 real ones, **6** are exercised only by a `#[CoversNothing]` integration test

## Types with real logic and zero mutants

| Package | Type | Kind | Only reached via `#[CoversNothing]` test |
|---|---|---|---|
| `json-ld` | `src/Context/ActiveContext.php` | class | no |
| `json-ld` | `src/Context/ContextProcessor.php` | class | no |
| `json-ld` | `src/Context/DefinitionScope.php` | class | no |
| `json-ld` | `src/Context/Syntax.php` | class | no |
| `json-ld` | `src/Context/TermDefinition.php` | class | no |
| `json-ld` | `src/Exception/ContextRecursionException.php` | class | no |
| `json-ld` | `src/Exception/DocumentLoadingException.php` | class | no |
| `json-ld` | `src/Exception/InvalidContextException.php` | class | no |
| `json-ld` | `src/Exception/InvalidInputException.php` | class | no |
| `json-ld` | `src/Exception/InvalidJsonException.php` | class | no |
| `json-ld` | `src/Exception/InvalidNQuadsException.php` | class | no |
| `json-ld` | `src/Exception/JsonLdException.php` | class | no |
| `json-ld` | `src/ExpandOptions.php` | class | no |
| `json-ld` | `src/ExpansionRun.php` | class | no |
| `json-ld` | `src/Graph/Graph.php` | class | no |
| `json-ld` | `src/Graph/Node.php` | class | no |
| `json-ld` | `src/Json.php` | class | no |
| `json-ld` | `src/Keywords.php` | class | no |
| `json-ld` | `src/Loader/InlineContextLoader.php` | class | no |
| `json-ld` | `src/Loader/LoadedContext.php` | class | no |
| `json-ld` | `src/NodeMap.php` | class | no |
| `json-ld` | `src/Rdf/BlankNode.php` | class | no |
| `json-ld` | `src/Rdf/Canonicalizer.php` | class | no |
| `json-ld` | `src/Rdf/JsonCanonicalizer.php` | class | no |
| `json-ld` | `src/Rdf/Literal.php` | class | no |
| `json-ld` | `src/Rdf/Quad.php` | class | no |
| `property-testing` | `src/Event/CorpusPruned.php` | class | no |
| `property-testing` | `src/Event/CorpusReplayed.php` | class | no |
| `property-testing` | `src/Event/CorpusStored.php` | class | no |
| `property-testing` | `src/Event/ExampleFinished.php` | class | no |
| `property-testing` | `src/Event/ExampleStarted.php` | class | no |
| `property-testing` | `src/Event/PropertyFinished.php` | class | no |
| `property-testing` | `src/Event/PropertyStarted.php` | class | no |
| `property-testing` | `src/Event/RunDiscarded.php` | class | no |
| `property-testing` | `src/Event/RunFailed.php` | class | no |
| `property-testing` | `src/Event/RunPassed.php` | class | no |
| `property-testing` | `src/Event/RunStarted.php` | class | no |
| `property-testing` | `src/Event/ShrinkAccepted.php` | class | no |
| `property-testing` | `src/Event/ShrinkTried.php` | class | no |
| `property-testing` | `src/Internal/MonotonicClock.php` | class | no |
| `property-testing` | `src/Internal/VerboseListener.php` | class | no |
| `payments` | `src/ForbiddenException.php` | class | no |
| `payments` | `src/Internal/Assert.php` | class | no |
| `payments` | `src/Internal/Types.php` | class | no |
| `payments` | `src/Internal/WebhookLimits.php` | class | no |
| `payments` | `src/MalformedResponseException.php` | class | no |
| `payments` | `src/NotFoundException.php` | class | no |
| `payments` | `src/PaymentException.php` | class | no |
| `payments` | `src/ProviderDeclinedException.php` | class | no |
| `payments` | `src/RateLimitedException.php` | class | no |
| `payments` | `src/RefundFailedException.php` | class | no |
| `payments` | `src/ServerException.php` | class | no |
| `payments` | `src/TransportException.php` | class | no |
| `payments` | `src/UnauthorizedException.php` | class | no |
| `doc-exec` | `src/BlockResult.php` | class | no |
| `doc-exec` | `src/Cli/UsageError.php` | class | no |
| `doc-exec` | `src/CodeBlock.php` | class | no |
| `doc-exec` | `src/Execution/BlockFailure.php` | class | no |
| `doc-exec` | `src/Execution/GeneratedScript.php` | class | no |
| `doc-exec` | `src/Execution/ProcessOutcome.php` | class | no |
| `doc-exec` | `src/Execution/ScriptSlot.php` | class | no |
| `doc-exec` | `src/Marker/ParsedMarker.php` | class | no |
| `doc-exec` | `src/Statement/Statement.php` | class | no |
| `doc-exec` | `src/Statement/StatementParseError.php` | class | no |
| `doc-exec` | `src/StatementResult.php` | class | no |
| `yii3-filestorage` | `src/Exception/AddException.php` | class | no |
| `yii3-filestorage` | `src/Exception/BlobBusyException.php` | class | no |
| `yii3-filestorage` | `src/Exception/ContentTooLargeException.php` | class | no |
| `yii3-filestorage` | `src/Exception/InvalidConfigException.php` | class | no |
| `yii3-filestorage` | `src/Exception/LedgerException.php` | class | no |
| `yii3-filestorage` | `src/Exception/PolicyViolationException.php` | class | no |
| `yii3-filestorage` | `src/Exception/RemoveException.php` | class | no |
| `yii3-filestorage` | `src/Exception/StoreException.php` | class | no |
| `yii3-filestorage` | `src/Exception/UploadFailedException.php` | class | no |
| `yii3-filestorage` | `src/Exception/UploadTooLargeException.php` | class | no |
| `property-testing-core` | `src/Event/TargetImproved.php` | class | no |
| `property-testing-core` | `src/Internal/PhaseCounters.php` | class | no |
| `property-testing-core` | `src/Runner/Redis/PhpRedisCorpusClient.php` | class | **yes** — RedisIntegrationTest.php |
| `property-testing-core` | `src/Runner/Redis/PredisCorpusClient.php` | class | **yes** — RedisIntegrationTest.php |
| `property-testing-core` | `src/Runner/SearchReport.php` | class | no |
| `property-testing-core` | `src/Runner/TargetOutcome.php` | class | no |
| `property-testing-core` | `src/StateMachine/Invariant.php` | class | no |
| `property-testing-core` | `src/StateMachine/Precondition.php` | class | no |
| `property-testing-core` | `src/StateMachine/Rule.php` | class | no |
| `quality-ledger` | `src/DiffEntry.php` | class | no |
| `quality-ledger` | `src/GateResult.php` | class | no |
| `quality-ledger` | `src/Internal/AbsentStatus.php` | class | no |
| `quality-ledger` | `src/Internal/RunRecord.php` | class | no |
| `quality-ledger` | `src/Internal/Transition.php` | class | no |
| `quality-ledger` | `src/StillBadEntry.php` | class | no |
| `quality-ledger` | `src/TrendPoint.php` | class | no |
| `link-preview` | `src/Adapter/OEmbedSupport.php` | class | no |
| `link-preview` | `src/Adapter/PageMetadata.php` | class | no |
| `link-preview` | `src/Extract/Json.php` | class | no |
| `link-preview` | `src/Extract/UrlContext.php` | class | no |
| `link-preview` | `src/Fetch/BlockedRanges.php` | class | no |
| `link-preview` | `src/Fetch/FetchedPage.php` | class | no |
| `openapi-contract` | `src/Internal/Reference/DeferredReference.php` | class | no |
| `openapi-contract` | `src/Internal/Schema/Backend/DecimalMultiple.php` | class | no |
| `openapi-contract` | `src/Internal/Schema/Backend/DecimalMultipleOfKeyword.php` | class | no |
| `openapi-contract` | `src/Internal/Schema/Backend/DecimalMultipleOfKeywordParser.php` | class | no |
| `openapi-contract` | `src/Internal/Schema/Backend/Draft.php` | class | no |
| `openapi-contract` | `src/Internal/Schema/Backend/Parser.php` | class | no |
| `property-testing-openapi` | `src/Internal/Compile/Unproducible.php` | class | no |
| `property-testing-openapi` | `src/Internal/ConstructibleCategories.php` | class | no |
| `property-testing-openapi` | `src/Internal/LazyPhpRedisCorpusClient.php` | class | no |
| `property-testing-openapi` | `src/Internal/MediaType.php` | class | no |
| `property-testing-openapi` | `src/Internal/SchemaShape.php` | class | no |
| `schema` | `src/NonRepresentable.php` | class | no |
| `schema` | `src/NonRepresentableException.php` | class | no |
| `schema` | `src/ParseResult.php` | class | no |
| `schema` | `src/SchemaType.php` | class | no |
| `schema` | `src/UnionBranch.php` | class | no |
| `understudy` | `src/Exception/AmbiguousDefaultFactory.php` | class | no |
| `understudy` | `src/Exception/BypassUnavailable.php` | class | no |
| `understudy` | `src/Exception/InvalidDefaultValue.php` | class | no |
| `understudy` | `src/Exception/OriginalCallUnavailable.php` | class | no |
| `understudy` | `src/Runtime/ReferenceSlot.php` | class | no |
| `yii3-metrics` | `src/FailOpenCounter.php` | class | no |
| `yii3-metrics` | `src/FailOpenGauge.php` | class | no |
| `yii3-metrics` | `src/FailOpenHistogram.php` | class | no |
| `yii3-metrics` | `src/FailOpenMeter.php` | class | no |
| `yii3-metrics` | `src/FailOpenUpDownCounter.php` | class | no |
| `payments-testing` | `src/Internal/AbstractFakeGateway.php` | class | no |
| `payments-testing` | `src/Internal/AttemptAssertions.php` | class | no |
| `payments-testing` | `src/Internal/FakeGatewayCore.php` | class | no |
| `payments-testing` | `src/Internal/Types.php` | class | no |
| `property-testing-phpunit` | `src/PhpUnit/PhpUnitTrialExecutor.php` | class | no |
| `property-testing-phpunit` | `src/PhpUnit/PropertyCheck.php` | class | no |
| `property-testing-phpunit` | `src/PhpUnit/PropertyTesting.php` | trait | no |
| `property-testing-phpunit` | `src/PhpUnit/VerboseListener.php` | class | no |
| `yii3-mcp` | `src/Interceptor/RequestEra.php` | class | no |
| `yii3-mcp` | `src/OpenApi/OperationRequestBuilder.php` | class | no |
| `yii3-mcp` | `src/OpenApi/OperationResponseDecoder.php` | class | no |
| `yii3-mcp` | `src/OpenApi/PlannedOperationRequest.php` | class | no |
| `yii3-ab-testing-db` | `src/Exception/ExperimentAlreadyExistsException.php` | class | no |
| `yii3-ab-testing-db` | `src/Exception/ExperimentNotFoundException.php` | class | no |
| `yii3-ab-testing-db` | `src/Exception/InvalidExperimentRowException.php` | class | no |
| `yii3-idempotency-redis` | `src/ClaimTokens.php` | class | no |
| `yii3-idempotency-redis` | `src/Redis/LuaScripts.php` | class | no |
| `yii3-idempotency-redis` | `src/UnexpectedRedisReplyException.php` | class | no |
| `yii3-outbox-db` | `src/Exception/OutboxWriteOutsideTransactionException.php` | class | **yes** — ConfigWiringTest.php |
| `yii3-outbox-db` | `src/Migration/M260820000000AddOutboxClaimedAt.php` | class | **yes** — CrossDatabaseMigrationTest.php, MigrationTest.php |
| `yii3-outbox-db` | `src/Migration/M261003000000AddOutboxPriority.php` | class | **yes** — CrossDatabaseMigrationTest.php, MigrationTest.php |
| `context` | `src/ContextException.php` | class | no |
| `context` | `src/HrTimeSource.php` | class | no |
| `yii3-idempotency` | `src/BufferedStream.php` | class | no |
| `yii3-idempotency` | `src/MissingKeyException.php` | class | no |
| `yii3-centrifugo` | `src/CentrifugoException.php` | class | no |
| `yii3-filestorage-attachments` | `src/Migration/M260814000000CreateFilestorageAttachmentTable.php` | class | **yes** — MigrationTest.php |
| `yii3-filestorage-db` | `src/Exception/InvalidFileRowException.php` | class | no |
| `yii3-maintenance-mode` | `src/IpMatcher.php` | class | no |
| `yii3-metrics-prometheus` | `src/EvalShaRedis.php` | class | no |
| `yii3-telemetry` | `src/HttpSpanSupport.php` | class | no |

## Trivial — listed for completeness

| Package | Type | Kind |
|---|---|---|
| `context-db` | `src/Dialect.php` | enum |
| `doc-exec` | `src/Marker/MarkerType.php` | enum |
| `doc-exec` | `src/Statement/StatementKind.php` | enum |
| `doc-exec` | `src/StatementOutcome.php` | enum |
| `link-preview` | `src/Adapter/AdapterFailure.php` | enum |
| `link-preview` | `src/Extract/ExtractFailure.php` | enum |
| `link-preview` | `src/Extract/JsonLdFailure.php` | enum |
| `link-preview` | `src/Fetch/FetchFailure.php` | enum |
| `link-preview` | `src/Fetch/UrlRejection.php` | enum |
| `media-converter` | `src/Internal/OutputMode.php` | enum |
| `media-converter` | `src/Operation/Position.php` | enum |
| `property-testing-core` | `src/Internal/ReplayVerdict.php` | enum |
| `resilience` | `src/PipelineOrder.php` | enum |
| `retry` | `src/Jitter/JitterMode.php` | enum |
| `schema` | `src/Format.php` | enum |
| `specification` | `src/LikeMatch.php` | enum |
| `understudy` | `src/Runtime/SequenceVerdict.php` | enum |
| `yii3-ab-testing-outbox` | `src/AbTestingOutboxEventType.php` | enum |
| `yii3-ab-testing-web` | `src/AnonymousToAuthenticatedStrategy.php` | enum |
| `yii3-ab-testing-web` | `src/SubjectIdSource.php` | enum |
| `yii3-centrifugo` | `src/Doctor/CheckCategory.php` | enum |
| `yii3-centrifugo` | `src/Doctor/CheckStatus.php` | enum |
| `yii3-filestorage-db` | `src/Command/Outcome.php` | enum |
| `yii3-health-check` | `src/HealthStatus.php` | enum |
| `yii3-idempotency` | `src/FailureKind.php` | enum |
| `yii3-webhooks` | `src/WebhookDeliveryStatus.php` | enum |
