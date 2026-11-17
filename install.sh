#!/usr/bin/env bash
# ==============================================================================
# Installer for odin-wasix (Public Zero-Dependency CLI)
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/satyaprakashere/odin-wasix/main/install.sh | bash
# ==============================================================================

set -eo pipefail

INSTALL_DIR="${HOME}/.local/bin"
LIB_DIR="${HOME}/.odin-wasix"

echo "⚡ Installing odin-wasix ..."

mkdir -p "$INSTALL_DIR" "$LIB_DIR"

SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

if [[ -f "${SCRIPT_SRC}/odin-wasix" && -d "${SCRIPT_SRC}/pkg/wasix" ]]; then
    # Local installation from cloned repo
    echo "--> Installing from local repository: ${SCRIPT_SRC}"
    cp "${SCRIPT_SRC}/odin-wasix" "${INSTALL_DIR}/odin-wasix"
    chmod +x "${INSTALL_DIR}/odin-wasix"
    rm -rf "${LIB_DIR}/pkg"
    cp -R "${SCRIPT_SRC}/pkg" "${LIB_DIR}/pkg"
else
    # Remote installation via curl
    echo "--> Downloading odin-wasix CLI..."
    curl -fsSL https://raw.githubusercontent.com/satyaprakashere/odin-wasix/main/odin-wasix -o "${INSTALL_DIR}/odin-wasix"
    chmod +x "${INSTALL_DIR}/odin-wasix"

    echo "--> Fetching WASIX Odin packages..."
    rm -rf "/tmp/odin-wasix-tmp"
    git clone --depth 1 https://github.com/satyaprakashere/odin-wasix.git "/tmp/odin-wasix-tmp"
    rm -rf "${LIB_DIR}/pkg"
    cp -R "/tmp/odin-wasix-tmp/pkg" "${LIB_DIR}/pkg"
    rm -rf "/tmp/odin-wasix-tmp"
fi

echo "✓ Successfully installed odin-wasix into ${INSTALL_DIR}/odin-wasix"
echo "✓ WASIX library packages installed into ${LIB_DIR}/pkg/wasix"

# PATH warning if not present
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    echo ""
    echo "⚠️  Note: ${INSTALL_DIR} is not in your PATH."
    echo "Add the following line to your shell profile (~/.bashrc, ~/.zshrc, or ~/.config/fish/config.fish):"
    echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
fi

echo ""
echo "🎉 Ready! Run 'odin-wasix help' or 'odin-wasix new my-app' to get started."
