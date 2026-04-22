#!/bin/bash

source scripts/shell/qemu_common.sh

set -eo pipefail

source "manifests/qemu/${BRANCH}/.env" || true

# --- Architecture mapping ---
# ARCH is already arm64/amd64 from qemu_common.sh; derive QEMU binary arch
IMG_ARCH="${ARCH}"
if [ "$IMG_ARCH" == "arm64" ]; then
    QEMU_ARCH="aarch64"
elif [ "$IMG_ARCH" == "amd64" ]; then
    QEMU_ARCH="x86_64"
else
    echo "Unsupported architecture: $IMG_ARCH"
    exit 1
fi
echo "Architecture: IMG_ARCH=${IMG_ARCH}, QEMU_ARCH=${QEMU_ARCH}"

# --- Determine distro ---
DISTRO="noble"
if [[ -f ".dockerargs" ]]; then
    DISTRO_FROM_FILE=$(grep -E '^DISTRO=' .dockerargs | cut -d'=' -f2 || echo "")
    if [[ -n "$DISTRO_FROM_FILE" ]]; then
        DISTRO="$DISTRO_FROM_FILE"
        echo "Using distro from .dockerargs: $DISTRO"
    fi
fi

# --- VM resource defaults ---
IDEKUBE_VM_MEMORY="${IDEKUBE_VM_MEMORY:-4G}"
IDEKUBE_VM_CPU="${IDEKUBE_VM_CPU:-2}"
IDEKUBE_VM_DISK_SIZE="${IDEKUBE_VM_DISK_SIZE:-10G}"

# --- Prepare cache directory ---
CACHE_DIR=".cache/${BRANCH}"
echo "Using cache directory: ${CACHE_DIR}"

mkdir -p "${CACHE_DIR}/images"
mkdir -p "${CACHE_DIR}/configs"
mkdir -p "${CACHE_DIR}/uefi"

# --- Copy base image to cache ---
TARGET_IMAGE="${CACHE_DIR}/images/root.img"
if [[ -n "$IDEKUBE_FROM" ]]; then
    SOURCE_IMAGE=".cache/${IDEKUBE_FROM}/images/root.img"
    echo "IDEKUBE_FROM is set: copying ${SOURCE_IMAGE} to ${TARGET_IMAGE}..."
else
    SOURCE_IMAGE=".cache/qemu_images/${DISTRO}-${IMG_ARCH}.img"
    echo "Copying ${SOURCE_IMAGE} to ${TARGET_IMAGE}..."
fi
cp "$SOURCE_IMAGE" "$TARGET_IMAGE"

# Copy configs and UEFI files
echo "Copying configuration and UEFI files..."
cp -r "artifacts/qemu/configs/"* "${CACHE_DIR}/configs/"
cp -r ".cache/qemu_files/"*.fd "${CACHE_DIR}/uefi/"

# Run cloud-init
docker run --rm -v "${CACHE_DIR}/configs/:/workspace" cloud-localds:latest cloud-localds \
    /workspace/cloud-init.iso /workspace/user-data.yaml /workspace/meta-data.yaml

CONTAINER_NAME="idekube-qemu-engine-${BRANCH//\//-}"

# Stop and remove existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping and removing existing container ${CONTAINER_NAME}..."
    docker stop -t 3 "${CONTAINER_NAME}" || true
    docker rm "${CONTAINER_NAME}" || true
fi

# --- Configuration ---
SSH_PORT="${IDEKUBE_SSH_PORT:-10022}"
MONITOR_PORT="${IDEKUBE_MONITOR_PORT:-10023}"
HTTP_PORT="${IDEKUBE_WEB_PORT:-8080}"

CACHE_ABS_PATH=$(cd "${CACHE_DIR}" && pwd)

# --- SSH helpers ---
SSH_PASS="idekube"
SSH_USER="idekube"
SSH_COMMON_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

vm_ssh() {
    sshpass -p "${SSH_PASS}" ssh ${SSH_COMMON_OPTS} -p "${SSH_PORT}" "${SSH_USER}@localhost" "$@"
}

vm_rsync() {
    sshpass -p "${SSH_PASS}" rsync -avz -e "ssh -p ${SSH_PORT} ${SSH_COMMON_OPTS}" "$@"
}

# --- VM lifecycle ---
VM_MODE=""  # "native" or "docker"
VM_PID=""

cleanup() {
    echo ""
    echo "Cleaning up..."

    if [[ "${VM_MODE}" == "native" ]]; then
        if [[ -n "${VM_PID}" ]] && kill -0 "${VM_PID}" 2>/dev/null; then
            echo "Killing QEMU process (PID: ${VM_PID})..."
            kill "${VM_PID}" 2>/dev/null || true
            sleep 2
            if kill -0 "${VM_PID}" 2>/dev/null; then
                kill -9 "${VM_PID}" 2>/dev/null || true
            fi
        fi
    elif [[ "${VM_MODE}" == "docker" ]]; then
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo "Stopping container ${CONTAINER_NAME}..."
            docker stop -t 3 "${CONTAINER_NAME}" 2>/dev/null || true
            docker rm "${CONTAINER_NAME}" 2>/dev/null || true
        fi
    fi

    echo "Cleanup complete."
}

trap cleanup EXIT
trap 'exit 1' SIGINT SIGTERM

# --- Launch VM: try native QEMU first ---
echo "Attempting to run VM natively..."
echo "Working directory: ${CACHE_ABS_PATH}"

if [[ -f "artifacts/qemu/startup-scripts/run.sh" ]]; then
    export IDEKUBE_VM_MEMORY
    export IDEKUBE_VM_CPU
    export IDEKUBE_VM_DISK_SIZE
    export IDEKUBE_SSH_PORT="${SSH_PORT}"
    export IDEKUBE_MONITOR_PORT="${MONITOR_PORT}"
    export IDEKUBE_WEB_PORT="${HTTP_PORT}"

    cd "${CACHE_ABS_PATH}" || { echo "Failed to cd to ${CACHE_ABS_PATH}"; exit 1; }

    if bash ../../../artifacts/qemu/startup-scripts/run.sh > "/tmp/qemu-${BRANCH//\//-}.log" 2>&1 &
    then
        VM_PID=$!
        VM_MODE="native"
        echo "✓ QEMU started natively (PID: ${VM_PID})"
        echo "  Log file: /tmp/qemu-${BRANCH//\//-}.log"

        cd - > /dev/null || true

        sleep 5

        if ! kill -0 "${VM_PID}" 2>/dev/null; then
            echo "✗ QEMU process died, checking logs..."
            tail -20 "/tmp/qemu-${BRANCH//\//-}.log"
            echo ""
            echo "Native mode failed, falling back to Docker..."
            VM_MODE=""
        fi
    else
        echo "✗ Failed to start QEMU natively"
        cd - > /dev/null || true
    fi
fi

# --- Launch VM: Docker fallback ---
if [[ -z "${VM_MODE}" ]]; then
    echo ""
    echo "Launching QEMU engine in Docker..."

    KVM_ARGS=()
    if [[ -e /dev/kvm ]]; then
        echo "✓ /dev/kvm detected"
        if grep -qE 'vmx|svm' /proc/cpuinfo 2>/dev/null; then
            echo "✓ CPU virtualization support detected"
            KVM_ARGS=(--device /dev/kvm)
        elif command -v lscpu &> /dev/null && lscpu | grep -qE 'Virtualization:.*\S'; then
            echo "✓ CPU virtualization support detected (lscpu)"
            KVM_ARGS=(--device /dev/kvm)
        fi
    fi

    if [[ ${#KVM_ARGS[@]} -gt 0 ]]; then
        echo "✓ Enabling KVM acceleration for container"
    else
        echo "⚠ KVM not available, using software emulation"
    fi

    docker run -d \
        --name "${CONTAINER_NAME}" \
        --privileged \
        "${KVM_ARGS[@]}" \
        -p "${SSH_PORT}:22" \
        -p "${MONITOR_PORT}:23" \
        -p "${HTTP_PORT}:80" \
        -v "${CACHE_ABS_PATH}:/var/lib/data" \
        -e IDEKUBE_VM_MEMORY="${IDEKUBE_VM_MEMORY}" \
        -e IDEKUBE_VM_CPU="${IDEKUBE_VM_CPU}" \
        -e IDEKUBE_VM_DISK_SIZE="${IDEKUBE_VM_DISK_SIZE}" \
        --workdir /var/lib/data \
        idekube-qemu-engine:latest \
        /run.sh

    VM_MODE="docker"

    echo "Waiting for container to start..."
    sleep 10

    echo "Container logs:"
    docker logs "${CONTAINER_NAME}" || true
fi

# --- Wait for SSH and provision ---
echo ""
echo "Testing SSH connection to localhost:${SSH_PORT}..."
MAX_RETRIES=30
RETRY_COUNT=0

if ! command -v sshpass &> /dev/null; then
    echo "Error: sshpass not found. Please install it:"
    echo "  macOS: brew install sshpass"
    echo "  Ubuntu/Debian: apt-get install sshpass"
    exit 1
fi

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if vm_ssh "echo 'SSH connection successful'" 2>/dev/null; then
        echo "✓ SSH connection established successfully!"
        echo ""

        # --- Provision VM ---
        FLAVOR=$(echo "$BRANCH" | cut -d'/' -f1)
        COMMON_ROOTFS="artifacts/qemu/rootfs"
        BRANCH_ROOTFS="artifacts/qemu/${FLAVOR}/rootfs"

        # Resolve the pre-built idekube-healthcheck binary for the VM arch;
        # Ansible installs it into the VM via a copy task.
        HEALTHCHECK_BINARY="$(pwd)/.cache/qemu_tools/idekube-healthcheck.${IMG_ARCH}"
        if [[ ! -f "${HEALTHCHECK_BINARY}" ]]; then
            echo "✗ idekube-healthcheck binary not found: ${HEALTHCHECK_BINARY}"
            echo "  Run 'make build_qemu_tools' (or 'python3 build.py qemu-build-tools') first."
            exit 1
        fi
        echo "✓ idekube-healthcheck binary resolved: ${HEALTHCHECK_BINARY}"

        # Rsync common rootfs first, then branch-specific overlay on top
        echo "Copying common rootfs from ${COMMON_ROOTFS}..."
        vm_rsync "${COMMON_ROOTFS}/" "${SSH_USER}@localhost:/tmp/rootfs/"
        if [[ -d "${BRANCH_ROOTFS}" ]]; then
            echo "Copying branch rootfs overlay from ${BRANCH_ROOTFS}..."
            vm_rsync "${BRANCH_ROOTFS}/" "${SSH_USER}@localhost:/tmp/rootfs/"
        fi
        echo "✓ rootfs copied successfully."

        # Apply ansible playbook
        PLAYBOOK="manifests/qemu/$BRANCH/install.yml"
        if [[ -f "${PLAYBOOK}" ]]; then
            echo "Applying ansible playbook: ${PLAYBOOK}..."
            if command -v ansible-playbook &> /dev/null; then
                if ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "localhost," \
                    --extra-vars "ansible_ssh_pass=${SSH_PASS} ansible_user=${SSH_USER} ansible_port=${SSH_PORT} idekube_healthcheck_binary=${HEALTHCHECK_BINARY}" \
                    -c ssh "${PLAYBOOK}"; then
                    echo "✓ Ansible playbook applied successfully!"
                else
                    echo "✗ Ansible playbook failed!"
                    exit 1
                fi
            else
                echo "Warning: ansible-playbook not found. Skipping playbook execution."
                echo "  Install: pip install ansible"
            fi
        else
            echo "Warning: Playbook not found: ${PLAYBOOK}"
        fi

        # Copy compiled frontend into nginx html root.
        # Must run AFTER the ansible playbook: the playbook apt-installs
        # nginx, whose nginx-common postinst populates /usr/share/nginx/html/
        # with a default index and would clobber anything placed there
        # earlier. Copying last ensures our index.html is the one that
        # sticks.
        if [[ -d "frontend/dist" ]]; then
            echo "Copying frontend dist to /usr/share/nginx/html/..."
            vm_rsync "frontend/dist/" "${SSH_USER}@localhost:/tmp/frontend-dist/"
            vm_ssh "sudo rsync -a /tmp/frontend-dist/ /usr/share/nginx/html/"
            vm_ssh "rm -rf /tmp/frontend-dist"
            echo "✓ Frontend dist copied successfully."
        else
            echo "Warning: frontend/dist not found, skipping landing page."
        fi

        # Gracefully shut down the guest so late writes (healthcheck binary,
        # systemd units, final rootfs rsync) actually land on the qcow2 disk.
        # QEMU's cache=writethrough only flushes what the guest submits —
        # the guest kernel's own page cache needs `sync` + a clean poweroff
        # (ext4 journal) or writes from the last ~30s are lost when the trap
        # SIGKILLs QEMU.
        echo "Flushing guest filesystem..."
        vm_ssh "sudo sync && sudo sync" || true

        echo "Powering off VM for clean shutdown..."
        # `systemctl poweroff` exits the SSH session as sshd is torn down,
        # so a non-zero exit here is expected.
        vm_ssh "sudo systemctl poweroff" || true

        # Wait up to 60s for QEMU/container to exit on its own.
        for _ in $(seq 1 30); do
            if [[ "${VM_MODE}" == "native" ]]; then
                kill -0 "${VM_PID}" 2>/dev/null || break
            else
                docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" || break
            fi
            sleep 2
        done

        if [[ "${VM_MODE}" == "native" ]] && kill -0 "${VM_PID}" 2>/dev/null; then
            echo "⚠ VM did not power off within 60s; cleanup trap will force-kill."
        elif [[ "${VM_MODE}" == "docker" ]] && docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo "⚠ Container did not exit within 60s; cleanup trap will force-stop."
        else
            echo "✓ VM powered off cleanly."
        fi

        echo ""
        echo "✓ VM provisioning completed successfully!"
        exit 0
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Waiting for SSH connection... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

echo "✗ Warning: SSH connection not established after ${MAX_RETRIES} attempts"
if [[ "${VM_MODE}" == "native" ]]; then
    echo "Check logs with: tail -f /tmp/qemu-${BRANCH//\//-}.log"
else
    echo "Container may still be starting up. Check logs with: docker logs -f ${CONTAINER_NAME}"
fi
exit 1
