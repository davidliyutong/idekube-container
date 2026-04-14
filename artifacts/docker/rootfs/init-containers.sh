#!/bin/bash

# check the id of the current user
CURRENT_UID=$(id -u)
if [ "$CURRENT_UID" -ne 0 ]; then
    echo "This script must be run as root. Current UID: $CURRENT_UID"
    exit 1
fi

# check if /rootfs is mounted to another volume
if ! mountpoint -q /rootfs; then
    echo "/rootfs is not mounted to another volume. Exiting."
    exit 0 # also exit successfully
else
    # check the /rootfs mountpoint
    echo "/rootfs is mounted to $(mountpoint -d /rootfs)."
fi

# Clean /rootfs
rm -rf /rootfs/* /rootfs/.*

# Use rsync to mirror the root filesystem to /rootfs with proper exclusions
chmod 755 /rootfs && chown root:root /rootfs

echo "Syncing root filesystem to /rootfs..."
rsync -aAXH --info=progress2 \
  --exclude=/rootfs \
  --exclude=/proc/* \
  --exclude=/sys/* \
  --exclude=/dev/* \
  --exclude=/run/* \
  --exclude=/tmp/* \
  --exclude=/mnt/* \
  --exclude=/media/* \
  --exclude=/var/tmp/* \
  --exclude=/var/run/* \
  --exclude=/lost+found \
  --exclude=/boot \
  / /rootfs/

# Create essential directories that were excluded
mkdir -p /rootfs/{proc,sys,dev,run,tmp,mnt,media,var/tmp,var/run}

# exit successfully
echo "Init container completed successfully."
exit 0