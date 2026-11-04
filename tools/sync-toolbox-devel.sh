#!/usr/bin/env bash
# Strict mode: exit immediately on pipeline failure, unhandled error, or unset variable
set -euo pipefail

# Invoked by tools/toolbox-update.sh; regenerates PATH shims for
# fedora-toolbox-devel (see tools/lib/toolbox-shim-sync.sh).

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=lib/toolbox-shim-sync.sh
source "${SCRIPT_DIR}/lib/toolbox-shim-sync.sh"

sync_toolbox_shims "devel" "/usr/local/google-cloud-sdk/bin"
