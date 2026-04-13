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
set +e
echo "Copying root disk image..."
mkdir -p ./images
cp -r "${SOURCE_DIR}/images/root.img" ./images/
set -e

# ------------------------------------------------------------------
# Generate dynamic cloud-init user-data.yaml
# ------------------------------------------------------------------
echo "Generating cloud-init user-data.yaml from environment..."

# Generate access_token.conf content based on IDEKUBE_ACCESS_TOKEN
generate_access_token_conf() {
    if [ -n "${IDEKUBE_ACCESS_TOKEN:-}" ] && printf '%s' "${IDEKUBE_ACCESS_TOKEN}" | grep -qE '^[A-Za-z0-9._:@%+-]+$'; then
        local token="${IDEKUBE_ACCESS_TOKEN}"
        cat <<EOF
map \$args \$__idekube_token_from_arg {
    default "";
    "~(?:^|&)idekube-container-access-token=([^&]*)" \$1;
}
map \$__idekube_token_from_arg \$__idekube_token_arg_ok {
    default 0;
    "${token}" 1;
}
map \$cookie_idekube_container_access_token \$__idekube_token_cookie_ok {
    default 0;
    "${token}" 1;
}
map \$http_x_idekube_container_access_token \$__idekube_token_header_ok {
    default 0;
    "${token}" 1;
}
map "\$__idekube_token_arg_ok:\$__idekube_token_cookie_ok:\$__idekube_token_header_ok" \$idekube_access_permitted {
    default 0;
    "~1" 1;
}
EOF
    else
        [ -n "${IDEKUBE_ACCESS_TOKEN:-}" ] && echo "Warning: IDEKUBE_ACCESS_TOKEN contains invalid characters, ignoring" >&2
        cat <<'EOF'
map $args $__idekube_token_from_arg { default ""; }
map $__idekube_token_from_arg $__idekube_token_arg_ok { default 0; }
map $cookie_idekube_container_access_token $__idekube_token_cookie_ok { default 0; }
map $http_x_idekube_container_access_token $__idekube_token_header_ok { default 0; }
map $request_uri $idekube_access_permitted { default 1; }
EOF
    fi
}

# Generate runtime-env content
generate_runtime_env() {
    echo "# IDEKube runtime environment"
    [ -n "${IDEKUBE_USER_UID:-}" ] && echo "IDEKUBE_USER_UID=${IDEKUBE_USER_UID}"
    [ -n "${IDEKUBE_AUTHORIZED_KEYS:-}" ] && echo "IDEKUBE_AUTHORIZED_KEYS=${IDEKUBE_AUTHORIZED_KEYS}"
    [ -n "${IDEKUBE_PREFERED_SHELL:-}" ] && echo "IDEKUBE_PREFERED_SHELL=${IDEKUBE_PREFERED_SHELL}"
    [ -n "${IDEKUBE_INIT_HOME:-}" ] && echo "IDEKUBE_INIT_HOME=${IDEKUBE_INIT_HOME}"
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

    # write_files entry: access_token.conf
    echo "  - path: /etc/nginx/conf.d/access_token.conf"
    echo "    content: |"
    generate_access_token_conf | sed 's/^/      /'
    echo "    owner: root:root"
    echo "    permissions: '0644'"

    # write_files entry: runtime-env
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
