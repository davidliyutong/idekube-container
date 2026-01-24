#!/bin/bash

# Parse configuration from environment variables
VM_MEMORY="${IDEKUBE_VM_MEMORY:-1G}"
VM_CPU="${IDEKUBE_VM_CPU:-1}"
VM_DISK_SIZE="${IDEKUBE_VM_DISK_SIZE:-}"
EXPOSE_MONITOR_PORT=${IDEKUBE_MONITOR_PORT:-23}
EXPOSE_SSH_PORT="${IDEKUBE_SSH_PORT:-22}"
EXPOSE_WEB_PORT="${IDEKUBE_WEB_PORT:-80}"


# Helper function to parse boolean flags
parse_bool() {
    local value=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "${value}" in
        1|true|yes|on) echo "1" ;;
        0|false|no|off|"") echo "0" ;;
        *) echo "0" ;;
    esac
}

HEADLESS=$(parse_bool "${IDEKUBE_VM_HEADLESS:-1}")
DISABLE_KVM=$(parse_bool "${IDEKUBE_VM_DISABLE_KVM:-0}")

# Detect accelerator
ARCH=$(uname -m)
if [[ "$(uname)" == "Darwin" ]]; then
    ACCELERATOR=" -accel hvf "
    CPU_TYPE="host"
elif [[ "$(uname)" == "Linux" ]]; then
    if [[ "${DISABLE_KVM}" != "1" ]] && [[ -e /dev/kvm ]] && (lsmod | grep -q kvm || [[ -d /sys/module/kvm ]]); then
        ACCELERATOR=" -accel kvm "
        CPU_TYPE="host"
    else
        ACCELERATOR=""
        echo "Warning: /dev/kvm not found, KVM acceleration disabled" >&2
        if [[ "${ARCH}" == "arm64" || "${ARCH}" == "aarch64" ]]; then
            CPU_TYPE="cortex-a72"
        elif [[ "${ARCH}" == "x86_64" ]]; then
            CPU_TYPE="qemu64,+aes,+ssse3,+sse4.1,+sse4.2,+avx,+avx2,+bmi2,+smep,+bmi1,+fma,+movbe"
        else
            echo "Unsupported architecture for CPU type detection" >&2
            exit 1
        fi
    fi
else
    echo "Unsupported OS for acceleration" >&2
    exit 1
fi
echo "Using CPU type: ${CPU_TYPE}, Acceleration: ${ACCELERATOR}"

# Graphics options
if [[ "${HEADLESS}" == "1" ]]; then
    GRAPHICS_OPTS="-nographic"
else
    GRAPHICS_OPTS="-device virtio-gpu-pci -display default,show-cursor=on -device qemu-xhci -device usb-kbd -device usb-tablet -device intel-hda -device hda-duplex"
fi

# Set QEMU binary and firmware based on architecture
if [[ "${ARCH}" == "arm64" || "${ARCH}" == "aarch64" ]]; then
    QEMU_BIN="qemu-system-aarch64"
    MACHINE_TYPE="virt"
    FIRMWARE_OPTS="-drive if=pflash,format=raw,readonly=on,file=./uefi/edk2-aarch64-code.fd -drive if=pflash,format=raw,file=./uefi/edk2-arm-vars.fd"
elif [[ "${ARCH}" == "x86_64" ]]; then
    QEMU_BIN="qemu-system-x86_64"
    MACHINE_TYPE="q35"
    # Check if OVMF firmware files exist, use them if available
    if [[ -f "./uefi/OVMF_CODE.fd" && -f "./uefi/OVMF_VARS.fd" ]]; then
        FIRMWARE_OPTS="-drive if=pflash,format=raw,readonly=on,file=./uefi/OVMF_CODE.fd -drive if=pflash,format=raw,file=./uefi/OVMF_VARS.fd"
    else
        FIRMWARE_OPTS=""
        echo "Warning: OVMF firmware not found, booting without UEFI" >&2
    fi
else
    echo "Unsupported architecture: ${ARCH}" >&2
    exit 1
fi

# Check if user network backend is available
NETWORK_OPTS=""
if ${QEMU_BIN} -machine ${MACHINE_TYPE} -netdev help 2>&1 | grep -q "user"; then
    NETWORK_OPTS="-netdev user,id=net0,hostfwd=tcp::${EXPOSE_SSH_PORT}-:22,hostfwd=tcp::${EXPOSE_WEB_PORT}-:80,hostfwd=tcp::5901-:5901 -device virtio-net-pci,netdev=net0,disable-modern=off,disable-legacy=on"
else
    echo "Warning: 'user' network backend not available, networking will be disabled" >&2
    NETWORK_OPTS=""
fi

# If cloud-localds exists, init the cloud-init drive
if command -v cloud-localds >/dev/null 2>&1; then
    echo "cloud-localds found, generating cloud-init.iso..."
    cloud-localds ./configs/cloud-init.iso ./configs/user-data.yaml ./configs/meta-data.yaml
else
    echo "cloud-localds not found, skipping cloud-init.iso generation."
fi

# Validate and resize root disk image
DISK_IMAGE="./images/root.img"

if [[ ! -f "${DISK_IMAGE}" ]]; then
    echo "Error: Disk image ${DISK_IMAGE} not found" >&2
    exit 1
fi

echo "Validating disk image..."
if ! qemu-img info "${DISK_IMAGE}" >/dev/null 2>&1; then
    echo "Error: Invalid disk image ${DISK_IMAGE}" >&2
    exit 1
fi

# Resize disk if VM_DISK_SIZE is specified
if [[ -n "${VM_DISK_SIZE}" ]]; then
    echo "Checking disk size..."
    CURRENT_SIZE=$(qemu-img info --output=json "${DISK_IMAGE}" | jq -r '."virtual-size"')

    # Parse target size to bytes (support G/M/K suffixes)
    TARGET_SIZE_STR="${VM_DISK_SIZE}"
    if [[ "${TARGET_SIZE_STR}" =~ ^([0-9]+)([GMK])?$ ]]; then
        TARGET_NUM="${BASH_REMATCH[1]}"
        TARGET_UNIT="${BASH_REMATCH[2]}"
        case "${TARGET_UNIT}" in
            G) TARGET_SIZE=$(echo "${TARGET_NUM} * 1024 * 1024 * 1024" | bc) ;;
            M) TARGET_SIZE=$(echo "${TARGET_NUM} * 1024 * 1024" | bc) ;;
            K) TARGET_SIZE=$(echo "${TARGET_NUM} * 1024" | bc) ;;
            *) TARGET_SIZE=${TARGET_NUM} ;;
        esac

        SHOULD_RESIZE=$(echo "${TARGET_SIZE} > ${CURRENT_SIZE}" | bc 2>/dev/null || echo "0")
        if [[ "${SHOULD_RESIZE}" == "1" ]]; then
            CURRENT_SIZE_GB=$(echo "scale=2; ${CURRENT_SIZE} / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "unknown")
            echo "Resizing disk from ${CURRENT_SIZE_GB}G to ${VM_DISK_SIZE}..."
            if ! qemu-img resize "${DISK_IMAGE}" "${VM_DISK_SIZE}"; then
                echo "Warning: Failed to resize disk image" >&2
            fi
        else
            echo "Disk size ${VM_DISK_SIZE} is not larger than current size (${CURRENT_SIZE}), skipping resize."
        fi
    else
        echo "Warning: Invalid disk size format: ${VM_DISK_SIZE}" >&2
    fi
fi

echo "Starting QEMU with monitor on telnet port ${EXPOSE_MONITOR_PORT}..."

${QEMU_BIN} \
    -M ${MACHINE_TYPE} \
    ${FIRMWARE_OPTS} \
    -cpu ${CPU_TYPE} \
    ${ACCELERATOR} \
    -m ${VM_MEMORY} \
    -smp ${VM_CPU},sockets=1,cores=${VM_CPU},threads=1 \
    ${GRAPHICS_OPTS} \
    -monitor telnet:0.0.0.0:${EXPOSE_MONITOR_PORT},server,nowait \
    -serial mon:stdio \
    -drive file=./images/root.img,format=qcow2,if=virtio,cache=writethrough,index=0,media=disk \
    -drive file=./configs/cloud-init.iso,index=1,media=cdrom \
    -boot order=c \
    ${NETWORK_OPTS}
