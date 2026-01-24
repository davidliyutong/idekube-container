#!/bin/bash

QEMU_VERSION="10.2.0"
QEMU_URL="https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz"
FILES_DIR="third_party/qemu_files"

# Download QEMU if not already present
if [ -f "${FILES_DIR}/qemu-${QEMU_VERSION}.tar.xz" ]; then
    echo "QEMU tarball already downloaded, skipping download..."
else
    echo "Downloading QEMU ${QEMU_VERSION}..."
    curl -L -o "${FILES_DIR}/qemu-${QEMU_VERSION}.tar.xz" "${QEMU_URL}"
fi

# Extract if not already extracted
if [ -d "${FILES_DIR}/qemu-${QEMU_VERSION}" ]; then
    echo "QEMU already extracted, skipping extraction..."
else
    echo "Extracting tarball..."
    tar -xf "${FILES_DIR}/qemu-${QEMU_VERSION}.tar.xz" -C "${FILES_DIR}"
fi

echo "Copying edk2-aarch64-code.fd.bz2 from pc-bios..."
cp "${FILES_DIR}/qemu-${QEMU_VERSION}/pc-bios/edk2-aarch64-code.fd.bz2" .
cp "${FILES_DIR}/qemu-${QEMU_VERSION}/pc-bios/edk2-arm-vars.fd.bz2" .

echo "Decompressing edk2-aarch64-code.fd.bz2..."
bunzip2 edk2-aarch64-code.fd.bz2
bunzip2 edk2-arm-vars.fd.bz2

echo "Moving edk2-aarch64-code.fd to assets..."
mv edk2-aarch64-code.fd "${FILES_DIR}/"
mv edk2-arm-vars.fd "${FILES_DIR}/"

echo "Done! edk2-aarch64-code.fd and edk2-arm-vars.fd are in ${FILES_DIR}/"