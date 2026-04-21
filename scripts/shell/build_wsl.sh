#!/usr/bin/env bash
# Host-side orchestrator for the QEMU → WSL2 rootfs converter.
#
# Produces .cache/<BRANCH>/images/wsl-rootfs.tar.gz from either:
#   (a) the local qcow2 at .cache/<BRANCH>/images/root.img (fast path), or
#   (b) an already-built QEMU container image (pulls root.img out via docker cp).
#
# Temporary dev tool — not wired into build.py or CI.
set -euo pipefail

source scripts/shell/qemu_common.sh

CACHE_DIR=".cache/${BRANCH}"
IMAGES_DIR="${CACHE_DIR}/images"
ROOT_IMG="${IMAGES_DIR}/root.img"
OUTPUT="${IMAGES_DIR}/wsl-rootfs.tar.gz"
TOOL_IMAGE="qemu-to-wsl:latest"
TOOL_DIR="tools/utility/qemu-to-wsl"

mkdir -p "${IMAGES_DIR}"

# --- Resolve source root.img ---
if [[ ! -f "${ROOT_IMG}" ]]; then
    echo "Local ${ROOT_IMG} not found. Trying to extract from container image ${IMAGE_REF}..."

    if ! docker image inspect "${IMAGE_REF}" >/dev/null 2>&1; then
        echo "✗ Container image ${IMAGE_REF} not found locally, and no qcow2 at ${ROOT_IMG}." >&2
        echo "  Run one of:" >&2
        echo "    make build_qemu_root BRANCH=${BRANCH}   # produces the qcow2" >&2
        echo "    make build_qemu      BRANCH=${BRANCH}   # produces the container image" >&2
        exit 1
    fi

    CID=$(docker create "${IMAGE_REF}")
    trap "docker rm -f ${CID} >/dev/null 2>&1 || true" EXIT
    docker cp "${CID}:/var/lib/idekube/images/root.img" "${ROOT_IMG}"
    docker rm -f "${CID}" >/dev/null 2>&1 || true
    trap - EXIT
    echo "✓ Extracted root.img from ${IMAGE_REF}"
fi

# --- Build converter image if missing ---
if ! docker image inspect "${TOOL_IMAGE}" >/dev/null 2>&1; then
    echo "Building ${TOOL_IMAGE} from ${TOOL_DIR}..."
    docker build -t "${TOOL_IMAGE}" "${TOOL_DIR}"
fi

# --- KVM probe (mirrors build_qemu_root.sh) ---
KVM_ARGS=()
if [[ -e /dev/kvm ]]; then
    if grep -qE 'vmx|svm' /proc/cpuinfo 2>/dev/null; then
        echo "✓ /dev/kvm + CPU virt detected — enabling KVM for libguestfs appliance"
        KVM_ARGS=(--device /dev/kvm)
    fi
fi
if [[ ${#KVM_ARGS[@]} -eq 0 ]]; then
    echo "⚠ KVM unavailable — libguestfs will run in TCG (slower)"
fi

# --- Run converter ---
IMAGES_ABS=$(cd "${IMAGES_DIR}" && pwd)

echo "Converting ${ROOT_IMG} → ${OUTPUT}..."
docker run --rm \
    "${KVM_ARGS[@]}" \
    -v "${IMAGES_ABS}:/workspace" \
    -e IN=/workspace/root.img \
    -e OUT=/workspace/wsl-rootfs.tar.gz \
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
    "${TOOL_IMAGE}"

SLUG="${BRANCH//\//-}"
echo ""
echo "✓ WSL rootfs ready: ${OUTPUT}"
echo ""
echo "To import on Windows (PowerShell / cmd):"
echo "  wsl --import idekube-${SLUG} C:\\wsl\\idekube-${SLUG} ${OUTPUT//\//\\}"
echo "  wsl -d idekube-${SLUG}"
