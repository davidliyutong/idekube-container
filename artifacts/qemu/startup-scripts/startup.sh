#!/bin/bash
#
# startup.sh — QEMU container entrypoint.
# Prepares the working directory, generates a dynamic cloud-init
# user-data.yaml from IDEKUBE_* environment variables, then launches
# the QEMU VM via run.sh.
#

set -e

WORK_DIR="/var/lib/data"
SOURCE_DIR="/var/lib/idekube"

echo "Preparing QEMU environment in ${WORK_DIR}..."

cd "${WORK_DIR}"

# Copy UEFI firmware files
echo "Copying UEFI firmware files..."
mkdir -p ./uefi
cp -r "${SOURCE_DIR}/uefi/"*.fd ./uefi/

# Copy configuration files (meta-data.yaml, etc.)
echo "Copying configuration files..."
mkdir -p ./configs
cp -r "${SOURCE_DIR}/configs/"* ./configs/

# Copy root disk image
echo "Copying root disk image..."
mkdir -p ./images
if ! cp -r "${SOURCE_DIR}/images/root.img" ./images/; then
    echo "Error: Failed to copy root disk image from ${SOURCE_DIR}/images/root.img" >&2
    echo "       The image may not have been built. Run 'make build_qemu_root' first." >&2
    exit 1
fi

# ------------------------------------------------------------------
# Patch the build-time user-data.yaml (copied above from ${SOURCE_DIR}/configs)
# for runtime: flip ssh_pwauth off and append a write_files entry for
# /etc/idekube/runtime-env plus a runcmd invoking vm-init.sh.
# ------------------------------------------------------------------
echo "Patching cloud-init user-data.yaml for runtime..."

USER_DATA="./configs/user-data.yaml"

# Generate runtime-env content.
# Values are single-quoted for safe shell-sourcing from vm-init.sh: this
# preserves multi-line values (e.g. unwrapped-base64 IDEKUBE_AUTHORIZED_KEYS
# produced by `base64` without -w 0) and values containing spaces or shell
# metacharacters (e.g. IDEKUBE_ACCESS_TOKEN).
# NOTE: IDEKUBE_ACCESS_TOKEN is included so that authn.sh (called by
# vm-init.sh at VM boot) can replace __IDEKUBE_ACCESS_TOKEN_PLACEHOLDER__
# in the baked-in /etc/nginx/conf.d/access_token.conf template.
write_runtime_var() {
    local name="$1" value="$2"
    # Escape embedded single quotes: ' -> '\''
    local escaped=${value//\'/\'\\\'\'}
    printf "%s='%s'\n" "$name" "$escaped"
}

generate_runtime_env() {
    echo "# IDEKube runtime environment"
    [ -n "${IDEKUBE_USER_UID:-}" ]        && write_runtime_var IDEKUBE_USER_UID        "$IDEKUBE_USER_UID"
    [ -n "${IDEKUBE_AUTHORIZED_KEYS:-}" ] && write_runtime_var IDEKUBE_AUTHORIZED_KEYS "$IDEKUBE_AUTHORIZED_KEYS"
    [ -n "${IDEKUBE_PREFERED_SHELL:-}" ]  && write_runtime_var IDEKUBE_PREFERED_SHELL  "$IDEKUBE_PREFERED_SHELL"
    [ -n "${IDEKUBE_INIT_HOME:-}" ]       && write_runtime_var IDEKUBE_INIT_HOME       "$IDEKUBE_INIT_HOME"
    [ -n "${IDEKUBE_ACCESS_TOKEN:-}" ]    && write_runtime_var IDEKUBE_ACCESS_TOKEN    "$IDEKUBE_ACCESS_TOKEN"
    return 0
}

# Build-time config enables password auth for Ansible; disable it at runtime.
sed -i 's/^ssh_pwauth:.*/ssh_pwauth: false/' "$USER_DATA"

# Append runtime-only sections. The build-time file has no write_files or
# runcmd keys, so appending as new top-level keys is safe.
{
    echo ""
    echo "write_files:"
    echo "  - path: /etc/idekube/runtime-env"
    echo "    content: |"
    generate_runtime_env | sed 's/^/      /'
    echo "    owner: root:root"
    echo "    permissions: '0600'"
    echo ""
    echo "runcmd:"
    echo "  - [bash, /etc/idekube/vm-init.sh]"
} >> "$USER_DATA"

echo "Environment preparation complete."
echo "Starting QEMU..."

exec /run.sh
