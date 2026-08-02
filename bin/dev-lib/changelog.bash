# changelog.bash — add entries to CHANGELOG.md "## Unreleased" sections
# (workstream D, reduced). Sourced by bin/dev; expects common.bash, POSARGS,
# DEV_DRY_RUN, DEV_TYPE.
#
# Section layout follows Keep a Changelog, matching the packages that already
# carry an Unreleased section:
#   ## Unreleased
#
#   ### <Type>
#
#   - <entry>

# Insert lines into a file before the given 0-based line index.
_splice() { # file index line...
  local file="$1" idx="$2"; shift 2
  local -a lines
  mapfile -t lines <"$file"
  printf '%s\n' "${lines[@]:0:idx}" "$@" "${lines[@]:idx}" >"$file"
}

# Add one entry to a package changelog.
# Returns: 0 = added, 1 = already present, 2 = no CHANGELOG.md.
_changelog_add_one() { # pkg type entry
  local file="$WORKSPACE_ROOT/$1/CHANGELOG.md" type="$2" entry="$3"
  [ -f "$file" ] || return 2

  local -a lines
  mapfile -t lines <"$file"
  local n="${#lines[@]}" i

  local unrel=-1 unrel_end="$n"
  for ((i = 0; i < n; i++)); do
    [ "${lines[$i]}" = "## Unreleased" ] && { unrel=$i; break; }
  done

  if [ "$unrel" -lt 0 ]; then
    # No Unreleased section: create it before the first version heading
    # (or at EOF for a fresh changelog).
    local ins="$n"
    for ((i = 0; i < n; i++)); do
      [[ "${lines[$i]}" == "## "* ]] && { ins=$i; break; }
    done
    _splice "$file" "$ins" "## Unreleased" "" "### $type" "" "- $entry" ""

    return 0
  fi

  for ((i = unrel + 1; i < n; i++)); do
    [[ "${lines[$i]}" == "## "* ]] && { unrel_end=$i; break; }
  done

  for ((i = unrel; i < unrel_end; i++)); do
    [ "${lines[$i]}" = "- $entry" ] && return 1
  done

  local tstart=-1 tend="$unrel_end"
  for ((i = unrel + 1; i < unrel_end; i++)); do
    [ "${lines[$i]}" = "### $type" ] && { tstart=$i; break; }
  done

  if [ "$tstart" -lt 0 ]; then
    # No such subsection yet: insert it right after "## Unreleased" (+ blank).
    local ins=$((unrel + 1))
    [ "$ins" -lt "$n" ] && [ -z "${lines[$ins]}" ] && ins=$((ins + 1))
    _splice "$file" "$ins" "### $type" "" "- $entry" ""

    return 0
  fi

  for ((i = tstart + 1; i < unrel_end; i++)); do
    [[ "${lines[$i]}" == "### "* ]] && { tend=$i; break; }
  done
  # Append after the last non-blank line of the subsection (keeps the blank
  # line that separates it from the next heading).
  local ins=$((tstart + 1))
  for ((i = tstart + 1; i < tend; i++)); do
    [ -n "${lines[$i]}" ] && ins=$((i + 1))
  done
  _splice "$file" "$ins" "- $entry"
}

# bin/dev changelog:add "<entry>" [--type=added|changed|fixed|removed|breaking] [pkgs] [--dry-run]
cmd_changelog_add() {
  local entry="${POSARGS[0]:-}"
  [ -n "$entry" ] || dev_die 'usage: bin/dev changelog:add "<entry>" [--type=added|changed|fixed|removed|breaking] [pkgs] [--dry-run]'
  local type="${DEV_TYPE:-changed}"
  case "$type" in
    added | changed | fixed | removed | breaking) type="${type^}" ;;
    *) dev_die "invalid --type '$type' (added|changed|fixed|removed|breaking)" ;;
  esac
  dev_select_packages "${POSARGS[1]:-}"

  local pkg n_added=0
  for pkg in "${PKGS[@]}"; do
    if [ ! -f "$WORKSPACE_ROOT/$pkg/CHANGELOG.md" ]; then
      dev_fail_row "$pkg" "no CHANGELOG.md"
      continue
    fi
    if [ "$DEV_DRY_RUN" = 1 ]; then
      dev_row "$pkg" "would add under ## Unreleased / ### $type: - $entry"
      continue
    fi
    _changelog_add_one "$pkg" "$type" "$entry"
    case $? in
      0) dev_row "$pkg" "added under ### $type"; n_added=$((n_added + 1)) ;;
      1) dev_row "$pkg" "already present, skipped" ;;
      *) dev_fail_row "$pkg" "failed to update CHANGELOG.md" ;;
    esac
  done
  [ "$DEV_DRY_RUN" = 1 ] || printf '%sadded in %d package(s)%s\n' "$C_BLD" "$n_added" "$C_RST" >&2

  dev_report_failures
}
