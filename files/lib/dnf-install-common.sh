# shellcheck shell=bash
# Shared helpers sourced by files/dnf-install-*.sh. Callers must set
# `set -euo pipefail` themselves before sourcing this file.

DNF="/usr/bin/dnf --assumeyes --quiet"

# install_resolved <pkg> [exclude-regex]
# Resolves <pkg> and its "<pkg>-*" subpackages via dnf repoquery, optionally
# dropping names matching <exclude-regex> (passed to `grep -vE`), then
# installs the resolved set. Exits 1 if the dnf install fails.
install_resolved() {
  local pkg="$1"
  local exclude_regex="${2:-}"

  echo "Installing packages for \"${pkg}\"..."
  local extra_pkgs
  if [ -n "${exclude_regex}" ]; then
    extra_pkgs=$(${DNF} repoquery --queryformat="%{NAME}\n" "${pkg}" "${pkg}"-* | grep -v -E "${exclude_regex}" | tr '\n' ' ')
  else
    extra_pkgs=$(${DNF} repoquery --queryformat="%{NAME}\n" "${pkg}" "${pkg}"-* | tr '\n' ' ')
  fi
  echo "Installing packages: ${extra_pkgs}"

  local cmd="${DNF} install ${extra_pkgs}"
  echo "Running: ${cmd}"
  if ! ${cmd}; then
    echo "Failure running: ${cmd}"
    exit 1
  fi
}
