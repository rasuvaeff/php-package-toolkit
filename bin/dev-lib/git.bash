# git.bash — batch git operations across package repositories (workstream B).
# Sourced by bin/dev; expects common.bash, POSARGS, DEV_DRY_RUN, DEV_STASH.
# Never suppresses git hooks. All git ops run serially: ordered output,
# and network ops (push/pull) stay easy to interrupt.


_git() {
  local pkg="$1"; shift
  git -C "$WORKSPACE_ROOT/$pkg" "$@"
}

_has_git() { [ -e "$WORKSPACE_ROOT/$1/.git" ]; }

_dirty() { [ -n "$(_git "$1" status --porcelain 2>/dev/null)" ]; }

_branch() { _git "$1" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?'; }

# bin/dev git:status [pkgs]
cmd_git_status() {
  dev_select_packages "${POSARGS[0]:-}"

  local pkg n_dirty=0 n_nogit=0
  for pkg in "${PKGS[@]}"; do
    if ! _has_git "$pkg"; then
      dev_row "$pkg" "${C_YEL}no git${C_RST}"
      n_nogit=$((n_nogit + 1))
      continue
    fi
    if _dirty "$pkg"; then
      dev_row "$pkg" "$(_branch "$pkg") ${C_RED}*dirty${C_RST}"
      n_dirty=$((n_dirty + 1))
    else
      dev_row "$pkg" "$(_branch "$pkg")"
    fi
  done
  printf '%s%d package(s), %d dirty, %d without git%s\n' \
    "$C_BLD" "${#PKGS[@]}" "$n_dirty" "$n_nogit" "$C_RST" >&2
  [ "$n_dirty" -eq 0 ]
}

# bin/dev git:branch [pkgs]
cmd_git_branch() {
  dev_select_packages "${POSARGS[0]:-}"

  local pkg
  for pkg in "${PKGS[@]}"; do
    _has_git "$pkg" || { dev_row "$pkg" "${C_YEL}no git${C_RST}"; continue; }
    dev_row "$pkg" "$(_git "$pkg" branch --format='%(if)%(HEAD)%(then)*%(end)%(refname:short)' | paste -sd ' ' -)"
  done
}

# bin/dev git:checkout [-b] <branch> [pkgs] [--stash] [--dry-run]
cmd_git_checkout() {
  local create=0 idx=0
  if [ "${POSARGS[0]:-}" = "-b" ]; then create=1; idx=1; fi
  local branch="${POSARGS[$idx]:-}"
  [ -n "$branch" ] || dev_die 'usage: bin/dev git:checkout [-b] <branch> [pkgs] [--stash] [--dry-run]'
  dev_select_packages "${POSARGS[$((idx + 1))]:-}"

  local pkg
  local -a dirty=()
  for pkg in "${PKGS[@]}"; do
    _has_git "$pkg" || dev_die "$pkg has no git repository"
    _dirty "$pkg" && dirty+=("$pkg")
  done
  if [ "${#dirty[@]}" -gt 0 ] && [ "$DEV_STASH" != 1 ] && [ "$DEV_DRY_RUN" != 1 ]; then
    dev_die "dirty working tree in: ${dirty[*]} (re-run with --stash or clean up first)"
  fi

  local -a co=(checkout)
  [ "$create" = 1 ] && co=(checkout -b)

  local out rc stashed
  for pkg in "${PKGS[@]}"; do
    if [ "$DEV_DRY_RUN" = 1 ]; then
      dev_row "$pkg" "would run: git ${co[*]} $branch$(_dirty "$pkg" && printf ' (dirty: stash push/pop)')"
      continue
    fi
    stashed=0
    if _dirty "$pkg"; then
      _git "$pkg" stash push -q -u >/dev/null || { dev_fail_row "$pkg" "stash push failed"; continue; }
      stashed=1
    fi
    out="$(_git "$pkg" "${co[@]}" "$branch" 2>&1)"; rc=$?
    if [ "$stashed" = 1 ] && ! _git "$pkg" stash pop -q 2>/dev/null; then
      dev_fail_row "$pkg" "stash pop conflict — resolve manually (git -C $pkg stash show)"
      continue
    fi
    if [ "$rc" -ne 0 ]; then
      dev_fail_row "$pkg" "$out"
    else
      dev_row "$pkg" "$(_branch "$pkg")"
    fi
  done
  dev_report_failures
}

# bin/dev git:commit "<msg>" [pkgs] [--dry-run]
cmd_git_commit() {
  local msg="${POSARGS[0]:-}"
  [ -n "$msg" ] || dev_die 'usage: bin/dev git:commit "<msg>" [pkgs] [--dry-run]'
  dev_select_packages "${POSARGS[1]:-}"

  local pkg out n_committed=0
  for pkg in "${PKGS[@]}"; do
    _has_git "$pkg" || { dev_fail_row "$pkg" "no git repository"; continue; }
    if ! _dirty "$pkg"; then
      dev_row "$pkg" "clean, skipped"
      continue
    fi
    if [ "$DEV_DRY_RUN" = 1 ]; then
      dev_row "$pkg" "would run: git add -A && git commit -m \"$msg\""
      continue
    fi
    if out="$(_git "$pkg" add -A 2>&1 && _git "$pkg" commit -q -m "$msg" 2>&1)"; then
      dev_row "$pkg" "committed $(_git "$pkg" rev-parse --short HEAD)"
      n_committed=$((n_committed + 1))
    else
      dev_fail_row "$pkg" "$out"
    fi
  done
  [ "$DEV_DRY_RUN" = 1 ] || printf '%scommitted in %d package(s)%s\n' "$C_BLD" "$n_committed" "$C_RST" >&2
  dev_report_failures
}

# bin/dev git:push [pkgs] [--dry-run]
cmd_git_push() {
  dev_select_packages "${POSARGS[0]:-}"

  local pkg out
  for pkg in "${PKGS[@]}"; do
    _has_git "$pkg" || { dev_fail_row "$pkg" "no git repository"; continue; }
    if ! _git "$pkg" remote get-url origin >/dev/null 2>&1; then
      dev_fail_row "$pkg" "no origin remote"
      continue
    fi
    if [ "$DEV_DRY_RUN" = 1 ]; then
      dev_row "$pkg" "would run: git push -u origin HEAD ($(_branch "$pkg"))"
      continue
    fi
    if out="$(_git "$pkg" push -u origin HEAD 2>&1)"; then
      dev_row "$pkg" "$(_branch "$pkg"): $(tail -n1 <<<"$out")"
    else
      dev_fail_row "$pkg" "$(tail -n1 <<<"$out")"
    fi
  done
  dev_report_failures
}

# bin/dev git:pull [pkgs]
cmd_git_pull() {
  dev_select_packages "${POSARGS[0]:-}"

  local pkg out
  for pkg in "${PKGS[@]}"; do
    _has_git "$pkg" || { dev_fail_row "$pkg" "no git repository"; continue; }
    if out="$(_git "$pkg" pull --ff-only 2>&1)"; then
      dev_row "$pkg" "$(head -n1 <<<"$out")"
    else
      dev_fail_row "$pkg" "$(tail -n1 <<<"$out")"
    fi
  done
  dev_report_failures
}
