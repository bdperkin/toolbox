#!/usr/bin/env bash
# Strict mode: exit immediately on pipeline failure, unhandled error, or unset variable
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=lib/dnf-install-common.sh
source "${SCRIPT_DIR}/lib/dnf-install-common.sh"

cat <<EOF >/etc/yum.repos.d/claude-code.repo
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/stable
enabled=1
gpgcheck=1
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
EOF

PKGS="
acli
ansible
chezmoi
claude-code
colordiff
gcc
gh
git-delta
glab
hadolint
jq
libatomic
libvirt-devel
libxcrypt-compat
make
nodejs
podman
pre-commit
ruff
ty
uv
xclip
"

PY_PKGS=$(${DNF} repoquery --queryformat="%{NAME}\n" --whatprovides python3\.*-devel | grep -P "^python3\.\d+-devel$" | sort -V | xargs -n 1)

EXCLUDE_REGEX="^(nodejs-backbone|nodejs-packaging|podman-machine|podman-tests|make-it-quick|make-it-quick-devel|vim-syntastic-vala)$"

for PKG in ${PY_PKGS} ${PKGS}; do
  install_resolved "${PKG}" "${EXCLUDE_REGEX}"
done

${DNF} clean all

for GBIN in /usr/local/google-cloud-sdk/bin/*; do
  ln -s "${GBIN}" /usr/bin/"$(basename "${GBIN}")"
done
