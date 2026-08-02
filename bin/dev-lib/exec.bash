# exec.bash — run shell commands across packages (workstream B).
# Sourced by bin/dev; expects common.bash, POSARGS.

# bin/dev exec "<cmd>" [pkgs] [--serial] [-jN]
cmd_exec() {
  local shellcmd="${POSARGS[0]:-}"
  [ -n "$shellcmd" ] || dev_die 'usage: bin/dev exec "<cmd>" [pkgs] [--serial] [-jN]'
  dev_select_packages "${POSARGS[1]:-}"

  dev_exec_in_packages "$shellcmd" "${PKGS[@]}"
}

# Sugar: bin/dev build|test|cs-fix|psalm [pkgs] → make <target> in each package.
cmd_make_target() {
  dev_select_packages "${POSARGS[0]:-}"

  dev_exec_in_packages "make $1" "${PKGS[@]}"
}
