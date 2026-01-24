#!/bin/bash

source scripts/shell/qemu_common.sh

set -e

source manifests/qemu/${BRANCH}/.env || true

# Determine cache directory from BRANCH
CACHE_DIR=".cache/${BRANCH}"
echo "Using cache directory: ${CACHE_DIR}"

# Create cache directory structure
echo "Creating cache directory structure..."
mkdir -p "${CACHE_DIR}/images"
mkdir -p "${CACHE_DIR}/configs"
mkdir -p "${CACHE_DIR}/uefi"

# Detect OS architecture
ARCH=$(uname -m)
if [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ]; then
    QEMU_ARCH="aarch64"
elif [ "$ARCH" == "x86_64" ]; then
    QEMU_ARCH="x86_64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
echo "Detected architecture: $ARCH -> QEMU arch: $QEMU_ARCH"

# Determine distro from .dockerargs or use default
DISTRO="noble"
if [[ -f ".dockerargs" ]]; then
    DISTRO_FROM_FILE=$(grep -E '^DISTRO=' .dockerargs | cut -d'=' -f2 || echo "")
    if [[ -n "$DISTRO_FROM_FILE" ]]; then
        DISTRO="$DISTRO_FROM_FILE"
        echo "Using distro from .dockerargs: $DISTRO"
    fi
fi

# Map architecture for image filename
if [ "$QEMU_ARCH" == "aarch64" ]; then
    IMG_ARCH="arm64"
elif [ "$QEMU_ARCH" == "x86_64" ]; then
    IMG_ARCH="amd64"
else
    echo "Error: Unable to map QEMU_ARCH '${QEMU_ARCH}' to image architecture"
    exit 1
fi
echo "Using image architecture: ${IMG_ARCH} for QEMU architecture: ${QEMU_ARCH}"

# Copy base image to cache
TARGET_IMAGE="${CACHE_DIR}/images/root.img"
if [[ -n "$IDEKUBE_FROM" ]]; then
    SOURCE_IMAGE=".cache/${IDEKUBE_FROM}/images/root.img"
    echo "IDEKUBE_FROM is set: copying ${SOURCE_IMAGE} to ${TARGET_IMAGE}..."
else
    SOURCE_IMAGE=".cache/qemu_images/${DISTRO}-${IMG_ARCH}.img"
    echo "Copying ${SOURCE_IMAGE} to ${TARGET_IMAGE}..."
fi
cp "$SOURCE_IMAGE" "$TARGET_IMAGE"

# Copy Configs, UEFI files
echo "Copying configuration and UEFI files..."
cp -r "artifacts/qemu/configs/"* "${CACHE_DIR}/configs/"
cp -r .cache/qemu_files/*.fd "${CACHE_DIR}/uefi/"

# Run cloud-init
docker run --rm -v ${CACHE_DIR}/configs/:/workspace cloud-localds:latest cloud-localds \
    /workspace/cloud-init.iso /workspace/user-data.yaml /workspace/meta-data.yaml

CONTAINER_NAME="idekube-qemu-engine-${BRANCH//\//-}"

# Stop and remove existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping and removing existing container ${CONTAINER_NAME}..."
    docker stop -t 3 "${CONTAINER_NAME}"|| true
    docker rm "${CONTAINER_NAME}" || true
fi

# Configuration
SSH_PORT="${IDEKUBE_SSH_PORT:-10022}"
MONITOR_PORT="${IDEKUBE_MONITOR_PORT:-10023}"
HTTP_PORT="${IDEKUBE_WEB_PORT:-8080}"

# Get absolute path for mounting
CACHE_ABS_PATH=$(cd "${CACHE_DIR}" && pwd)

# Variables to track VM mode
VM_MODE=""  # "native" or "docker"
VM_PID=""

# Cleanup function for signal handling
cleanup() {
    echo ""
    echo "Caught interrupt signal, cleaning up..."

    if [[ "${VM_MODE}" == "native" ]]; then
        # Kill QEMU process
        if [[ -n "${VM_PID}" ]] && kill -0 "${VM_PID}" 2>/dev/null; then
            echo "Killing QEMU process (PID: ${VM_PID})..."
            kill "${VM_PID}" 2>/dev/null || true
            sleep 2
            # Force kill if still running
            if kill -0 "${VM_PID}" 2>/dev/null; then
                kill -9 "${VM_PID}" 2>/dev/null || true
            fi
        fi

        # Pkill any remaining QEMU processes
        echo "Killing any remaining QEMU processes..."
        pkill -f "qemu-system-${QEMU_ARCH}" 2>/dev/null

    elif [[ "${VM_MODE}" == "docker" ]]; then
        # Stop and remove Docker container
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo "Stopping container ${CONTAINER_NAME}..."
            docker stop -t 3 "${CONTAINER_NAME}" 2>/dev/null || true
            docker rm "${CONTAINER_NAME}" 2>/dev/null || true
        fi
    fi

    echo "Cleanup complete."
}

# Set up trap for Ctrl-C (SIGINT) and SIGTERM
trap cleanup SIGINT SIGTERM

# Try native QEMU first
echo "Attempting to run VM natively..."
echo "Working directory: ${CACHE_ABS_PATH}"

if [[ -f "artifacts/qemu/startup-scripts/run.sh" ]]; then
    # Export environment variables for run.sh
    export IDEKUBE_VM_MEMORY="${IDEKUBE_VM_MEMORY:-4G}"
    export IDEKUBE_VM_CPU="${IDEKUBE_VM_CPU:-2}"
    export IDEKUBE_VM_DISK_SIZE="${IDEKUBE_VM_DISK_SIZE:-10G}"
    export IDEKUBE_SSH_PORT="${SSH_PORT}"
    export IDEKUBE_MONITOR_PORT="${MONITOR_PORT}"
    export IDEKUBE_WEB_PORT="${HTTP_PORT}"

    # Try to run natively
    cd "${CACHE_ABS_PATH}"

    if bash ../../../artifacts/qemu/startup-scripts/run.sh > /tmp/qemu-${BRANCH//\//-}.log 2>&1 &
    then
        VM_PID=$!
        VM_MODE="native"
        echo "✓ QEMU started natively (PID: ${VM_PID})"
        echo "  Log file: /tmp/qemu-${BRANCH//\//-}.log"

        # Return to project root
        cd - > /dev/null

        # Give QEMU time to start
        sleep 5

        # Check if process is still running
        if ! kill -0 "${VM_PID}" 2>/dev/null; then
            echo "✗ QEMU process died, checking logs..."
            tail -20 /tmp/qemu-${BRANCH//\//-}.log
            echo ""
            echo "Native mode failed, falling back to Docker..."
            VM_MODE=""
        fi
    else
        echo "✗ Failed to start QEMU natively"
        cd - > /dev/null
    fi
fi

# Fallback to Docker if native failed
if [[ -z "${VM_MODE}" ]]; then
    echo ""
    echo "Launching QEMU engine in Docker..."

    # Detect KVM support
    KVM_SUPPORT=false
    KVM_ARGS=""

    if [[ -e /dev/kvm ]]; then
        echo "✓ /dev/kvm detected"
        # Check CPU virtualization support
        if grep -qE 'vmx|svm' /proc/cpuinfo 2>/dev/null; then
            echo "✓ CPU virtualization support detected"
            KVM_SUPPORT=true
        elif command -v lscpu &> /dev/null && lscpu | grep -qE 'Virtualization:.*\S'; then
            echo "✓ CPU virtualization support detected (lscpu)"
            KVM_SUPPORT=true
        fi
    fi

    if [[ "${KVM_SUPPORT}" == true ]]; then
        echo "✓ Enabling KVM acceleration for container"
        KVM_ARGS="--device /dev/kvm"
    else
        echo "⚠ KVM not available, using software emulation"
    fi

    docker run -d \
        --name "${CONTAINER_NAME}" \
        --privileged \
        ${KVM_ARGS} \
        -p "${SSH_PORT}:22" \
        -p "${MONITOR_PORT}:${MONITOR_PORT}" \
        -p "${HTTP_PORT}:80" \
        -v "${CACHE_ABS_PATH}:/var/lib/data" \
        -e IDEKUBE_VM_MEMORY="4G" \
        -e IDEKUBE_VM_CPU="2" \
        -e IDEKUBE_VM_DISK_SIZE="${IDEKUBE_VM_DISK_SIZE:-10G}" \
        idekube-qemu-engine:latest \
        /startup.sh

    VM_MODE="docker"

    echo "Waiting for container to start..."
    sleep 10

    # Show container logs
    echo "Container logs:"
    docker logs "${CONTAINER_NAME}" || true
fi

# Test SSH connection
echo ""
echo "Testing SSH connection to localhost:${SSH_PORT}..."
MAX_RETRIES=30
RETRY_COUNT=0

# Check if sshpass is available
if ! command -v sshpass &> /dev/null; then
    echo "Warning: sshpass not found. Please install it:"
    echo "  macOS: brew install sshpass"
    echo "  Ubuntu/Debian: apt-get install sshpass"
    cleanup
    exit 1
fi

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if sshpass -p "idekube" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "${SSH_PORT}" idekube@localhost "echo 'SSH connection successful'" 2>/dev/null; then
        echo "✓ SSH connection established successfully!"
        echo ""

        # COPY ROOTFS
        BRANCH_V1=$(echo "$BRANCH" | cut -d'/' -f1)
        SRC_ROOTFS="artifacts/qemu/${BRANCH_V1}/rootfs"
        echo "Copying rootfs from ${SRC_ROOTFS} to / via scp..."
        if [[ -d "${SRC_ROOTFS}" ]]; then
            sshpass -p "idekube" rsync -avz -e "ssh -p ${SSH_PORT} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" ${SRC_ROOTFS}/ idekube@localhost:/tmp/rootfs/
            echo "✓ rootfs copied successfully."
        else
            echo "Warning: rootfs directory not found: ${SRC_ROOTFS}"
        fi

        # Apply ansible playbook
        PLAYBOOK="manifests/qemu/$BRANCH/install.yml"
        if [[ -f "${PLAYBOOK}" ]]; then
            echo "Applying ansible playbook: ${PLAYBOOK}..."
            if command -v ansible-playbook &> /dev/null; then
                if ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "localhost," \
                    --extra-vars "ansible_ssh_pass=idekube ansible_user=idekube ansible_port=${SSH_PORT}" \
                    -c ssh "${PLAYBOOK}"; then
                    echo "✓ Ansible playbook applied successfully!"
                else
                    echo "✗ Ansible playbook failed!"
                    cleanup
                    exit 1
                fi
            else
                echo "Warning: ansible-playbook not found. Skipping playbook execution."
                echo "  Install: pip install ansible"
            fi
        else
            echo "Warning: Playbook not found: ${PLAYBOOK}"
        fi

        echo ""
        echo "✓ VM provisioning completed successfully!"
        cleanup
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
cleanup
exit 1
