# replicate.bash — propagate templates/ into packages (workstream A).
# Sourced by bin/dev; expects common.bash, POSARGS, DEV_DRY_RUN.

_load_manifest() {
  local manifest="$WORKSPACE_ROOT/replicate/manifest.bash"
  [ -f "$manifest" ] || dev_die "manifest not found: $manifest"
  source "$manifest"
  [ "${#REPLICATE_FILES[@]}" -gt 0 ] || dev_die "REPLICATE_FILES is empty in $manifest"

  local f
  for f in "${REPLICATE_FILES[@]}"; do
    [ -f "$WORKSPACE_ROOT/templates/$f" ] || dev_die "manifest lists '$f' but templates/$f does not exist"
  done
}

# Diff status for one package: prints space-separated list of files that
# differ from (or are missing in) the package; empty output = in sync.
_replicate_drift() { # pkg
  local pkg="$1" f
  for f in "${REPLICATE_FILES[@]}"; do
    cmp -s "$WORKSPACE_ROOT/templates/$f" "$WORKSPACE_ROOT/$pkg/$f" || printf '%s ' "$f"
  done
}

# bin/dev replicate:check [pkgs]
cmd_replicate_check() {
  _load_manifest
  dev_select_packages "${POSARGS[0]:-}"

  local pkg drift n_drift=0
  for pkg in "${PKGS[@]}"; do
    drift="$(_replicate_drift "$pkg")"
    if [ -n "$drift" ]; then
      dev_row "$pkg" "${C_RED}drift:${C_RST} $drift"
      n_drift=$((n_drift + 1))
    fi
  done
  printf '%s%d package(s), %d with drift%s\n' "$C_BLD" "${#PKGS[@]}" "$n_drift" "$C_RST" >&2

  [ "$n_drift" -eq 0 ]
}

# bin/dev replicate:files [--dry-run] [pkgs]
cmd_replicate_files() {
  _load_manifest
  dev_select_packages "${POSARGS[0]:-}"

  local pkg f drift n_changed=0
  for pkg in "${PKGS[@]}"; do
    drift="$(_replicate_drift "$pkg")"
    if [ -z "$drift" ]; then
      continue
    fi
    if [ "$DEV_DRY_RUN" = 1 ]; then
      dev_row "$pkg" "would copy: $drift"
      continue
    fi
    for f in $drift; do
      mkdir -p "$(dirname "$WORKSPACE_ROOT/$pkg/$f")"
      cp "$WORKSPACE_ROOT/templates/$f" "$WORKSPACE_ROOT/$pkg/$f" || { dev_fail_row "$pkg" "copy failed: $f"; continue 2; }
    done
    dev_row "$pkg" "updated: $drift"
    n_changed=$((n_changed + 1))
  done
  [ "$DEV_DRY_RUN" = 1 ] || printf '%supdated %d package(s)%s\n' "$C_BLD" "$n_changed" "$C_RST" >&2

  dev_report_failures
}

# bin/dev replicate:copy-file <src> <dst> [pkgs] [--dry-run]
# src is relative to the workspace root (or absolute); dst is relative to
# each package root.
cmd_replicate_copy_file() {
  local src="${POSARGS[0]:-}" dst="${POSARGS[1]:-}"
  [ -n "$src" ] && [ -n "$dst" ] || dev_die 'usage: bin/dev replicate:copy-file <src> <dst> [pkgs] [--dry-run]'
  [[ "$src" = /* ]] || src="$WORKSPACE_ROOT/$src"
  [ -f "$src" ] || dev_die "source file not found: $src"
  dev_select_packages "${POSARGS[2]:-}"

  local pkg
  for pkg in "${PKGS[@]}"; do
    if cmp -s "$src" "$WORKSPACE_ROOT/$pkg/$dst"; then
      dev_row "$pkg" "up to date"
      continue
    fi
    if [ "$DEV_DRY_RUN" = 1 ]; then
      dev_row "$pkg" "would copy → $dst"
      continue
    fi
    mkdir -p "$(dirname "$WORKSPACE_ROOT/$pkg/$dst")"
    if cp "$src" "$WORKSPACE_ROOT/$pkg/$dst"; then
      dev_row "$pkg" "copied → $dst"
    else
      dev_fail_row "$pkg" "copy failed"
    fi
  done

  dev_report_failures
}
