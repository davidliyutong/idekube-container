#!/bin/bash

# check if /rootfs is mounted to another volume
if ! mountpoint -q /rootfs; then
  echo "/rootfs is not mounted to another volume. Exiting."
  exit 0 # also exit successfully
fi
# check the /rootfs mountpoint
echo "/rootfs is mounted to $(mountpoint -d /rootfs)."
# check if /rootfs is not empty and IDEKUBE_INIT_ROOT is not set
if [ "$(ls -A /rootfs)" ] && [ -z "$IDEKUBE_INIT_ROOT" ]; then
  echo "/rootfs is not empty and IDEKUBE_INIT_ROOT is not set. Exiting."
  exit 0 # also exit successfully
fi

# Clean /rootfs
rm -rf /rootfs/* /rootfs/.*
# Use tar to copy the root filesystem to /rootfs (exclude /rootfs from source)
tar --exclude=/rootfs --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run --exclude=/tmp --exclude=/mnt --exclude=/media --exclude=/var/tmp --exclude=/var/run --exclude=/lost+found --exclude=/boot -cf - / | tar -C /rootfs -xf -
# exit successfully
echo "Init container completed successfully."
exit 0