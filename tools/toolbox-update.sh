#!/usr/bin/env bash
#
# toolbox-update.sh
# Synchronizes bashrc fragments, manages/updates toolbox containers,
# and installs local utility wrappers into ~/.local/bin.

set -euo pipefail
IFS=$'\n\t'

# Trap unexpected errors with line numbers and offending commands
trap 'echo >&2 "[ERROR] Command failed at line ${LINENO}: \"${BASH_COMMAND}\" (exit code: $?)"' ERR

# --- Formatting & Logging Helpers ---
if [[ -t 2 ]]; then
  readonly C_RESET='\033[0m'
  readonly C_RED='\033[0;31m'
  readonly C_GREEN='\033[0;32m'
  readonly C_YELLOW='\033[0;33m'
  readonly C_BLUE='\033[0;34m'
else
  readonly C_RESET=''
  readonly C_RED=''
  readonly C_GREEN=''
  readonly C_YELLOW=''
  readonly C_BLUE=''
fi

log_info() { printf "%b[INFO]%b  %s\n" "${C_BLUE}" "${C_RESET}" "$*" >&2; }
log_success() { printf "%b[OK]%b    %s\n" "${C_GREEN}" "${C_RESET}" "$*" >&2; }
log_warn() { printf "%b[WARN]%b  %s\n" "${C_YELLOW}" "${C_RESET}" "$*" >&2; }
log_error() { printf "%b[ERROR]%b %s\n" "${C_RED}" "${C_RESET}" "$*" >&2; }

# --- Path & Environment Discovery ---
SCRIPT_ABSOLUTE="$(readlink -f "${BASH_SOURCE[0]}")"
TOOLS_DIR="$(dirname "${SCRIPT_ABSOLUTE}")"
TOOLBOX_DIR="$(dirname "${TOOLS_DIR}")"

# Target directories & registries (configurable via environment variables)
readonly BASHRC_D="${BASHRC_D:-${HOME}/.bashrc.d}"
readonly LOCAL_BIN="${LOCAL_BIN:-${HOME}/.local/bin}"
readonly IMAGE_REGISTRY="${IMAGE_REGISTRY:-registry.fedoraproject.org}"

# --- Pre-flight Checks ---
check_prerequisites() {
  local missing=()
  for cmd in podman toolbox cmp cp ln; do
    if ! command -v "${cmd}" &>/dev/null; then
      missing+=("${cmd}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required executable(s): ${missing[*]}"
    exit 1
  fi

  # Ensure destination directories exist
  mkdir -p "${BASHRC_D}" "${LOCAL_BIN}"
}

# --- Container Reconciliation ---
reconcile_container() {
  local container_name="$1"
  local image_uri="${IMAGE_REGISTRY}/${container_name}"

  log_info "Reconciling container '${container_name}'..."

  # Check if container exists before inspecting or stopping
  if podman container exists "${container_name}" 2>/dev/null; then
    local is_running
    is_running="$(podman container inspect --format '{{.State.Running}}' "${container_name}" 2>/dev/null || true)"

    if [[ "${is_running}" == "true" ]]; then
      log_info "Stopping running container '${container_name}'..."
      podman stop "${container_name}" >/dev/null
    fi

    log_info "Removing existing container '${container_name}'..."
    # Attempt clean toolbox removal, falling back to podman force-rm if corrupted
    toolbox rm --force "${container_name}" >/dev/null 2>&1 \
      || podman rm -f "${container_name}" >/dev/null 2>&1 \
      || true
  fi

  log_info "Pulling image '${image_uri}'..."
  podman pull "${image_uri}"

  log_info "Creating toolbox '${container_name}'..."
  toolbox create --image "${image_uri}" "${container_name}"
  log_success "Toolbox '${container_name}' successfully provisioned."
}

# --- Module: Synchronize Bashrc Fragments ---
sync_bashrcs() {
  local src_dir="${TOOLBOX_DIR}/bashrcs"

  if [[ ! -d "${src_dir}" ]]; then
    log_warn "Directory '${src_dir}' not found. Skipping bashrc sync."
    return 0
  fi

  # Shared helpers sourced by the per-flavor fragments below.
  if [[ -d "${src_dir}/lib" ]]; then
    mkdir -p "${BASHRC_D}/lib"
    cp -af "${src_dir}"/lib/. "${BASHRC_D}/lib/"
  fi

  shopt -s nullglob
  local files=("${src_dir}"/*.sh)
  shopt -u nullglob

  if [[ ${#files[@]} -eq 0 ]]; then
    log_info "No .sh files found in '${src_dir}'."
    return 0
  fi

  for src in "${files[@]}"; do
    local filename="${src##*/}"
    local stem="${filename%.*}"
    local dst="${BASHRC_D}/${stem}"

    # Silent check: copy only if destination is missing or contents differ
    if [[ ! -f "${dst}" ]] || ! cmp -s "${src}" "${dst}"; then
      log_info "Updating bashrc fragment: ${stem} -> ${dst}"
      cp -af "${src}" "${dst}"
    else
      log_info "Fragment '${stem}' is up-to-date."
    fi

    reconcile_container "${stem}"
  done
}

# --- Module: Synchronize & Execute Tools ---
sync_tools() {
  local src_dir="${TOOLBOX_DIR}/tools"

  if [[ ! -d "${src_dir}" ]]; then
    log_warn "Directory '${src_dir}' not found. Skipping tools sync."
    return 0
  fi

  # Shared helpers sourced by the per-flavor tools below.
  if [[ -d "${src_dir}/lib" ]]; then
    mkdir -p "${LOCAL_BIN}/lib"
    cp -af "${src_dir}"/lib/. "${LOCAL_BIN}/lib/"
  fi

  shopt -s nullglob
  local files=("${src_dir}"/*.sh)
  shopt -u nullglob

  for src in "${files[@]}"; do
    # Avoid self-referential execution or linking
    if [[ "${src}" -ef "${SCRIPT_ABSOLUTE}" ]]; then
      continue
    fi

    local filename="${src##*/}"
    local stem="${filename%.*}"
    local dst="${LOCAL_BIN}/${filename}"
    local link="${LOCAL_BIN}/${stem}"

    # Install if missing, contents differ, or target symlink is broken
    if [[ ! -f "${dst}" ]] || ! cmp -s "${src}" "${dst}" || [[ ! -L "${link}" ]]; then
      log_info "Installing utility: ${filename}"
      cp -af "${src}" "${dst}"
      chmod +x "${dst}"

      # Create/replace relative symlink (<stem> -> <filename>) without directory hopping
      ln -sfn "${filename}" "${link}"
      log_success "Linked ${stem} -> ${filename}"
    fi

    # Execute wrapper if runnable
    if [[ -x "${link}" ]]; then
      log_info "Executing ${stem}..."
      "${link}"
    else
      log_warn "Target '${link}' is not executable. Skipping execution."
    fi
  done
}

# --- Main Entry Point ---
main() {
  check_prerequisites
  sync_bashrcs
  sync_tools
  log_success "All synchronizations completed."
}

main "$@"
