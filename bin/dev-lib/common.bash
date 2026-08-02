# common.bash — enumeration, selector expansion, parallel runner, logging.
# Sourced by bin/dev; expects WORKSPACE_ROOT to be set.

if [ -t 1 ]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_BLD=$'\033[1m'; C_RST=$'\033[0m'
else
  C_RED=''; C_GRN=''; C_YEL=''; C_BLD=''; C_RST=''
fi

dev_die() {
  printf '%serror:%s %s\n' "$C_RED" "$C_RST" "$1" >&2
  exit 1
}

dev_log() {
  printf '%s%s%s\n' "$C_BLD" "$1" "$C_RST" >&2
}

# All package directories: top-level dirs with a composer.json that carries no
# {{...}} placeholders (excludes templates/, which does have a composer.json).
dev_list_packages() {
  local d
  for d in "$WORKSPACE_ROOT"/*/; do
    [ -f "$d/composer.json" ] || continue
    grep -q '{{' "$d/composer.json" && continue
    basename "$d"
  done
}

# Expand a selector (empty = all, comma list, glob, @alias; forms combinable
# via commas) into package names, one per line. Dies if any part matches
# nothing. Duplicates removed, order preserved.
dev_expand_selector() {
  local sel="${1:-}"
  local -a all=()
  mapfile -t all < <(dev_list_packages)

  if [ -z "$sel" ] || [ "$sel" = "--all" ]; then
    printf '%s\n' "${all[@]}"
    return
  fi

  local -a parts=() out=()
  IFS=',' read -ra parts <<<"$sel"

  local part pat pkg matched
  for part in "${parts[@]}"; do
    [ -n "$part" ] || continue
    case "$part" in
      @*) pat="$(dev_alias_pattern "$part")" || dev_die "unknown alias '$part' (known: ${!DEV_ALIASES[*]})" ;;
      *) pat="$part" ;;
    esac
    matched=0
    for pkg in "${all[@]}"; do
      # shellcheck disable=SC2254
      case "$pkg" in
        $pat) out+=("$pkg"); matched=1 ;;
      esac
    done
    [ "$matched" -eq 1 ] || dev_die "selector '$part' matches no package"
  done

  printf '%s\n' "${out[@]}" | awk '!seen[$0]++'
}

# Per-package result rows and failure accounting, shared by serial commands
# (git:*, replicate:*, changelog:*).
FAILED=()

dev_row() { # pkg text...
  local pkg="$1"; shift
  printf '%-38s %s\n' "$pkg" "$*"
}

dev_fail_row() { # pkg message
  dev_row "$1" "${C_RED}FAIL${C_RST} $2"
  FAILED+=("$1")
}

dev_report_failures() {
  if [ "${#FAILED[@]}" -gt 0 ]; then
    printf '%sFAILED (%d/%d):%s %s\n' "$C_RED" "${#FAILED[@]}" "${#PKGS[@]}" "$C_RST" "${FAILED[*]}" >&2
    return 1
  fi
}

# Expand a selector into the global PKGS array; exits non-zero if the
# selector matched nothing (error already printed by dev_expand_selector).
dev_select_packages() {
  mapfile -t PKGS < <(dev_expand_selector "${1:-}")
  [ "${#PKGS[@]}" -gt 0 ] || exit 1
}

# Run a shell command in each package directory. Output is buffered per
# package and printed as a block, in spawn order (FIFO reaping: `wait -n`
# in bash < 5.3 misses jobs that terminated before the call, plain
# `wait <pid>` does not).
# Usage: dev_exec_in_packages "<cmd>" pkg...
# Honors DEV_JOBS (default: nproc) and DEV_SERIAL=1.
# Returns non-zero if any package failed.
dev_exec_in_packages() {
  local cmd="$1"; shift
  local -a pkgs=("$@")
  local jobs="${DEV_JOBS:-$(nproc)}"
  [ "${DEV_SERIAL:-0}" = "1" ] && jobs=1

  local tmpdir
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/dev-exec.XXXXXX")"
  local -a pids=() failed=()
  local head=0

  _dev_reap_head() {
    local pid="${pids[$head]}" donepkg="${pkgs[$head]}" rc
    head=$((head + 1))
    wait "$pid"; rc=$?
    printf '%s=== %s ===%s\n' "$C_BLD" "$donepkg" "$C_RST"
    cat "$tmpdir/$donepkg.log"
    if [ "$rc" -ne 0 ]; then
      printf '%s--- exit: %d ---%s\n' "$C_RED" "$rc" "$C_RST"
      failed+=("$donepkg")
    fi
  }

  local pkg
  for pkg in "${pkgs[@]}"; do
    (cd "$WORKSPACE_ROOT/$pkg" && bash -c "$cmd") >"$tmpdir/$pkg.log" 2>&1 &
    pids+=("$!")
    while [ $((${#pids[@]} - head)) -ge "$jobs" ]; do _dev_reap_head; done
  done
  while [ "$head" -lt "${#pids[@]}" ]; do _dev_reap_head; done

  rm -rf "$tmpdir"

  if [ "${#failed[@]}" -gt 0 ]; then
    printf '%sFAILED (%d/%d):%s %s\n' "$C_RED" "${#failed[@]}" "${#pkgs[@]}" "$C_RST" "${failed[*]}" >&2
    return 1
  fi

  printf '%sOK:%s %d package(s)\n' "$C_GRN" "$C_RST" "${#pkgs[@]}" >&2
}
