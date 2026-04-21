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
# Generate dynamic cloud-init user-data.yaml
# ------------------------------------------------------------------
echo "Generating cloud-init user-data.yaml from environment..."

# Generate runtime-env content.
# NOTE: IDEKUBE_ACCESS_TOKEN is included so that authn.sh (called by
# vm-init.sh at VM boot) can replace __IDEKUBE_ACCESS_TOKEN_PLACEHOLDER__
# in the baked-in /etc/nginx/conf.d/access_token.conf template.
generate_runtime_env() {
    echo "# IDEKube runtime environment"
    [ -n "${IDEKUBE_USER_UID:-}" ]        && echo "IDEKUBE_USER_UID=${IDEKUBE_USER_UID}"
    [ -n "${IDEKUBE_AUTHORIZED_KEYS:-}" ] && echo "IDEKUBE_AUTHORIZED_KEYS=${IDEKUBE_AUTHORIZED_KEYS}"
    [ -n "${IDEKUBE_PREFERED_SHELL:-}" ]  && echo "IDEKUBE_PREFERED_SHELL=${IDEKUBE_PREFERED_SHELL}"
    [ -n "${IDEKUBE_INIT_HOME:-}" ]       && echo "IDEKUBE_INIT_HOME=${IDEKUBE_INIT_HOME}"
    [ -n "${IDEKUBE_ACCESS_TOKEN:-}" ]    && echo "IDEKUBE_ACCESS_TOKEN=${IDEKUBE_ACCESS_TOKEN}"
    return 0
}

# Assemble user-data.yaml
{
    cat <<'HEADER'
#cloud-config
users:
  - name: idekube
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    groups: [sudo, video]

chpasswd:
  list: |
    idekube:idekube
  expire: False

ssh_pwauth: false

timezone: Asia/Shanghai

write_files:
HEADER

    # write_files entry: runtime-env
    # The access_token.conf template is already baked into the VM image;
    # authn.sh reads IDEKUBE_ACCESS_TOKEN from runtime-env and does the
    # placeholder replacement (or writes a permit-all config) at VM boot.
    echo "  - path: /etc/idekube/runtime-env"
    echo "    content: |"
    generate_runtime_env | sed 's/^/      /'
    echo "    owner: root:root"
    echo "    permissions: '0600'"

    cat <<'FOOTER'

runcmd:
  - [bash, /etc/idekube/vm-init.sh]

network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false
FOOTER
} > ./configs/user-data.yaml

echo "Environment preparation complete."
echo "Starting QEMU..."

exec /run.sh
