# aliases.bash — package-family aliases for the selector (@name → glob).

declare -A DEV_ALIASES=(
  [@ab]='yii3-ab-testing*'
  [@audit]='yii3-audit-log*'
  [@clickhouse]='*clickhouse-toolkit'
  [@filestorage]='yii3-filestorage*'
  [@flags]='yii3-feature-flags*'
  [@idempotency]='yii3-idempotency*'
  [@mcp]='yii3-mcp*'
  [@metrics]='yii3-metrics*'
  [@outbox]='yii3-outbox*'
  [@rector]='rector-*'
  [@settings]='yii3-settings*'
  [@telemetry]='yii3-telemetry*'
  [@tenancy]='yii3-tenancy*'
  [@webhooks]='yii3-webhooks*'
  [@workflow]='yii3-workflow*'
  [@utm]='yii3-utm*'
  [@property-testing]='property-testing*'

)

# Resolve @alias to its glob; non-zero if unknown.
dev_alias_pattern() {
  local alias="$1"
  [ -n "${DEV_ALIASES[$alias]:-}" ] || return 1
  printf '%s' "${DEV_ALIASES[$alias]}"
}
