#!/bin/bash
set -e

HERMES_VERSION=${HERMES_VERSION:-main}

# Load nvm so npm/node are on PATH
export NVM_DIR="/usr/local/nvm"
. "$NVM_DIR/nvm.sh"

# --- System dependencies not in agent/base ---
apt-get update && apt-get install -y --no-install-recommends ripgrep \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install uv (Python package manager required by hermes installer)
curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh

# --- Install Hermes Agent ---
# The upstream installer clones the repo directly into the --dir path,
# creates a venv at <dir>/venv, and installs Python 3.11 via uv.
#
# Key constraints:
#   - We use a throwaway HOME so nothing lands in /home/idekube (which
#     will be shadowed by a volume mount at runtime).
#   - UV_PYTHON_INSTALL_DIR must point to a persistent path inside
#     /opt/hermes, otherwise the venv's Python symlink breaks when the
#     throwaway HOME is deleted.
IDEKUBE_USER=${USERNAME:-idekube}

BUILD_HOME=$(mktemp -d)
export HOME="$BUILD_HOME"
export UV_PYTHON_INSTALL_DIR="/opt/uv-python"

curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/${HERMES_VERSION}/scripts/install.sh \
    | bash -s -- --dir /opt/hermes --skip-setup --branch ${HERMES_VERSION}
rm -rf "$BUILD_HOME"

# Symlink hermes binary to system PATH (repo root has a launcher script)
ln -sf /opt/hermes/venv/bin/hermes /usr/local/bin/hermes

hermes version || true

# --- Default config template ---
# Copy the example config so the bootstrap script can restore it on
# volume-mounted homes without network access.
mkdir -p /opt/hermes/default-config
cp /opt/hermes/cli-config.yaml.example \
    /opt/hermes/default-config/config.yaml 2>/dev/null || true

# --- Permissions ---
chown -R "$IDEKUBE_USER:$IDEKUBE_USER" /opt/hermes

# --- Cleanup ---
rm -rf /tmp/pip-* /tmp/uv-*
