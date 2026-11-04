# shellcheck shell=bash
# Shared helper sourced by bashrcs/<flavor>.sh fragments.

# ensure_toolbox <container-name>
# Makes sure the named toolbox container exists and is running, creating it
# from an image of the same name if necessary. No-ops when run from inside a
# container, from a non-interactive shell, or when podman/toolbox aren't
# available.
ensure_toolbox() {
  local container="$1"

  # 1. Guard: Never run this check from inside a container
  if [ -f /run/.containerenv ] || [ -f /run/.toolboxenv ]; then
    return 0
  fi

  # 2. Guard: Only run in interactive shells and ensure tools exist
  [[ $- == *i* ]] || return 0
  command -v podman &>/dev/null && command -v toolbox &>/dev/null || return 0

  local status
  status=$(podman container inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "missing")

  case "$status" in
    "running")
      # Already active; nothing to do
      ;;
    "missing")
      echo "Toolbox container '$container' not found. Creating..."
      toolbox create --image "$container" --container "$container"
      podman start "$container" >/dev/null
      echo "Toolbox container '$container' created and started."
      ;;
    *)
      # Container exists but is stopped or paused; start it in the background
      podman start "$container" >/dev/null
      ;;
  esac
}
