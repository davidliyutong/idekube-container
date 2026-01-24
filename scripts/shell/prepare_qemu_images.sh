#!/bin/bash

ARCHS=("arm64" "amd64")
DISTRO="noble"
IMAGE_ENDPOINT="cloud-images.ubuntu.com"
FILES_DIR="third_party/qemu_images"
TAG="20260108"

echo "Creating directories..."
mkdir -p "${FILES_DIR}"

for ARCH in "${ARCHS[@]}"; do
    if [ ! -f "${FILES_DIR}/${DISTRO}-${ARCH}.img" ]; then
        echo "Downloading Base Image for ${ARCH}..."
        wget -O ${FILES_DIR}/${DISTRO}-${ARCH}.img https://${IMAGE_ENDPOINT}/${DISTRO}/${TAG}/${DISTRO}-server-cloudimg-${ARCH}.img
    else
        echo "Base Image for ${ARCH} Present"
    fi
done

# VDISK_SIZE=10G
# if [ ! -f "assets/${DISTRO}-${ARCH}.qcow2" ]; then
#     echo "Creating the diff image"
#     pushd assets
#     qemu-img create -f qcow2 -o backing_file=${DISTRO}-${ARCH}.img,backing_fmt=qcow2 ${DISTRO}-${ARCH}.qcow2 ${VDISK_SIZE}
#     popd
# fi