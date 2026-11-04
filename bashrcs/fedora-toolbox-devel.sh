# shellcheck shell=bash
# Ensure fedora-toolbox-devel exists and is running
BASHRC_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
# shellcheck source=lib/ensure-toolbox.sh
source "${BASHRC_LIB_DIR}/ensure-toolbox.sh"
ensure_toolbox "fedora-toolbox-devel"

export PATH="$HOME/.local/share/toolbx-shims/fedora-toolbox-devel/bin:$PATH"
