# shellcheck shell=bash
# Shared helper sourced by tools/sync-toolbox-<flavor>.sh. Callers must set
# `set -euo pipefail` themselves before sourcing this file.

USR_BIN="/usr/bin"
BASENAME="${USR_BIN}/basename"
BASH="${USR_BIN}/bash"
CHMOD="${USR_BIN}/chmod"
DNF=("${USR_BIN}/dnf" "--assumeyes" "--quiet")
FIND="${USR_BIN}/find"
GREP="${USR_BIN}/grep"
JQ="${USR_BIN}/jq --raw-output"
LN="${USR_BIN}/ln --symbolic --force --no-dereference"
MKDIR="${USR_BIN}/mkdir --parents"
RPMQL=("${USR_BIN}/rpm" "--query" "--list")
SORT="${USR_BIN}/sort --numeric-sort"
XARGSN="${USR_BIN}/xargs --max-args 1"

# sync_toolbox_shims <group> [extra-container-bin-dir]
# Regenerates the PATH shim directory for the toolbox container named
# "fedora-toolbox-<group>" by discovering binaries the container's installed
# packages provide (via `dnf history`) and symlinking each one to a single
# dispatcher that execs it inside the container. If
# <extra-container-bin-dir> is given, every file directly under it inside
# the container is also shimmed (for tools installed outside dnf, e.g. an
# SDK unpacked into /usr/local).
sync_toolbox_shims() {
  local group="$1"
  local extra_bin_dir="${2:-}"

  local container="fedora-toolbox-${group}"
  local toolbox_run=("${USR_BIN}/toolbox" "run" "--container" "${container}")
  local shim_dir="${HOME}/.local/share/toolbx-shims/${container}"
  local bin_dir="${shim_dir}/bin"
  local dispatcher="${shim_dir}/dispatcher"

  local dnf_str toolbox_run_str
  printf -v dnf_str "%s " "${DNF[@]}"
  dnf_str="${dnf_str% }"
  printf -v toolbox_run_str "%s " "${toolbox_run[@]}"
  toolbox_run_str="${toolbox_run_str% }"

  # 0. Prepare shim-specific 'bin' directory
  ${MKDIR} "${bin_dir}"
  "${FIND}" "${bin_dir}" -type l -delete

  # 1. Create the universal dispatcher
  cat <<EOF >"${dispatcher}"
#!${BASH}
CMD=\$(${BASENAME} "\$0")
exec ${toolbox_run_str} ${USR_BIN}/\${CMD} "\$@"
EOF
  ${CHMOD} +x "${dispatcher}"

  # 2. Dynamically discover binaries provided by installed packages and refresh symlinks
  echo "Querying ${container} for installed binaries..."

  local bin_files
  bin_files=$(${toolbox_run_str} "${DNF[@]}" history list --json \
    | ${JQ} ".[] | select(.command_line | startswith(\"${dnf_str} install \")) | .id" \
    | ${SORT} \
    | ${XARGSN} "${toolbox_run[@]}" "${DNF[@]}" history info --json \
    | ${JQ} ".[].packages.[].nevra" \
    | ${XARGSN} "${toolbox_run[@]}" "${RPMQL[@]}" \
    | ${GREP} ^${USR_BIN}/ \
    | ${XARGSN} ${BASENAME})

  local extra_bin_files=""
  if [ -n "${extra_bin_dir}" ]; then
    extra_bin_files=$(${toolbox_run_str} ls "${extra_bin_dir}")
  fi

  local count=0
  for bin_file in ${bin_files} ${extra_bin_files}; do
    if [ ! -e "${USR_BIN}"/"${bin_file}" ]; then
      ${LN} "${dispatcher}" "${bin_dir}"/"${bin_file}"
      ((count = count + 1))
    fi
  done
  echo "Successfully linked ${count} container binaries to ${bin_dir}"
}
