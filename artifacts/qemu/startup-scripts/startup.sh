#!/bin/bash

set -e

# Working directory where the script will be executed from
WORK_DIR="/var/lib/data"
SOURCE_DIR="/var/lib/idekube"

echo "Preparing QEMU environment in ${WORK_DIR}..."

# Change to working directory
cd "${WORK_DIR}"

# Copy UEFI firmware files
echo "Copying UEFI firmware files..."
mkdir -p ./uefi
cp -r "${SOURCE_DIR}/uefi/"*.fd ./uefi/

# Copy configuration files
echo "Copying configuration files..."
mkdir -p ./configs
cp -r "${SOURCE_DIR}/configs/"* ./configs/

# Copy root disk image
set +e
echo "Copying root disk image..."
mkdir -p ./images
cp -r "${SOURCE_DIR}/images/root.img" ./images/
set -e

echo "Environment preparation complete."
echo "Starting QEMU..."


# Execute the run.sh script
exec /run.sh
