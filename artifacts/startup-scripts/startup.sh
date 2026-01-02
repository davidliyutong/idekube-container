#!/bin/bash

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# check if I_AM_INIT_CONTAINER is set
if [ -z "${I_AM_INIT_CONTAINER:-}" ]; then
  echo "I_AM_INIT_CONTAINER variable is not set. Skipping..."
else
  echo "I_AM_INIT_CONTAINER variable is set."
  bash /init-container.sh
  exit $?
fi

# Detect if /rootfs is mounted to another volume
if mountpoint -q /rootfs; then
    echo "/rootfs is mounted to $(mountpoint -d /rootfs)."

    # Function to safely mount with check
    safe_mount() {
        local source=$1
        local target=$2
        local options=${3:-"--bind"}

        # Check if source exists
        if [ ! -e "$source" ]; then
            echo "Source $source does not exist, skipping mount"
            return 0
        fi

        mkdir -p "$target" || { echo "Failed to create $target"; return 1; }

        # Check if already mounted
        if mountpoint -q "$target"; then
            echo "$target is already mounted, skipping"
            return 0
        fi

        # Perform mount
        if mount $options "$source" "$target"; then
            echo "Successfully mounted $source to $target"
            return 0
        else
            echo "Failed to mount $source to $target"
            return 1
        fi
    }

    # Cleanup function for unmounting on error
    cleanup_mounts() {
        echo "Cleaning up mounts..."
        for dir in /rootfs/var/run /rootfs/tmp /rootfs/run /rootfs/sys /rootfs/proc /rootfs/dev; do
            if mountpoint -q "$dir"; then
                umount -l "$dir" 2>/dev/null || true
            fi
        done
    }

    # Set trap to cleanup on error
    trap cleanup_mounts EXIT

    # Mount necessary filesystems
    safe_mount /dev /rootfs/dev "--rbind" || exit 1
    safe_mount /proc /rootfs/proc "--rbind" || exit 1
    safe_mount /sys /rootfs/sys "--rbind" || exit 1
    safe_mount /run /rootfs/run "--bind" || exit 1
    safe_mount /tmp /rootfs/tmp "--bind" || exit 1
    safe_mount /var/run /rootfs/var/run "--bind" || exit 1

    # Copy resolv.conf for DNS resolution
    if [ -f /etc/resolv.conf ]; then
        mkdir -p /rootfs/etc
        cp -a /etc/resolv.conf /rootfs/etc/resolv.conf || echo "Warning: Failed to copy resolv.conf"
        cp -a /etc/resolv.conf /rootfs/etc/resolv.conf || echo "Warning: Failed to copy resolv.conf"
        cp -a /etc/hosts /rootfs/etc/hosts || echo "Warning: Failed to copy hosts file"
        cp -a /etc/hostname /rootfs/etc/hostname || echo "Warning: Failed to copy hostname file"
        cp -a /etc/localtime /rootfs/etc/localtime || echo "Warning: Failed to copy localtime file"
        cp -a /etc/timezone /rootfs/etc/timezone || echo "Warning: Failed to copy timezone file"
    fi

    # Remove trap before chroot (cleanup will be handled by the system)
    trap - EXIT

    # Chroot and continue startup
    echo "Chrooting to /rootfs and executing /startup.sh"
    cp /startup.sh /rootfs/startup.sh # Ensure startup.sh is available in /rootfs and is the latest version
    chroot /rootfs /bin/bash /startup.sh
    exit $?
else
    echo "/rootfs is not mounted to another volume. Continuing startup in current rootfs."
fi

set +e  # Disable exit on error for the main script body

USER=${USERNAME:-root}
if [ "$USER" != "root" ]; then
    HOME=/home/$USER
else
    HOME=/root
fi

# Remove any existing lock files
rm -f /tmp/.X*-lock 2>/dev/null || true
rm -f /tmp/.X11-unix/X* 2>/dev/null || true

# ------------------------------------------------------
# response to IDEKUBE_PREFERED_SHELL
# ------------------------------------------------------
IDEKUBE_PREFERED_SHELL=${IDEKUBE_PREFERED_SHELL:-"/bin/bash"}
if [ -f "$IDEKUBE_PREFERED_SHELL" ]; then
    echo "Setting shell to $IDEKUBE_PREFERED_SHELL"
    if usermod -s "$IDEKUBE_PREFERED_SHELL" "$USER"; then
        echo "Shell changed successfully"
    else
        echo "Warning: Failed to change shell for $USER"
    fi
else
    echo "Shell $IDEKUBE_PREFERED_SHELL not found, keeping default"
fi

# ------------------------------------------------------
# response to IDEKUBE_INIT_HOME
# ------------------------------------------------------
if [ -n "${IDEKUBE_INIT_HOME:-}" ] || [ -z "$(ls -A "$HOME" 2>/dev/null)" ]; then
    echo "Initializing home folder"
    if [ -d /etc/skel ]; then
        rsync -r /etc/skel/ "$HOME/" 2>/dev/null || echo "Warning: Failed to sync skel to home"
        chown -R "$USER:$USER" "$HOME" 2>/dev/null || echo "Warning: Failed to change ownership of home"
    else
        echo "Warning: /etc/skel directory not found"
    fi
else
    echo "Skipping home folder initialization"
fi

# ------------------------------------------------------
# response to IDEKUBE_AUTHORIZED_KEYS
# ------------------------------------------------------
if [ ! -d "$HOME/.ssh" ]; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    if ! su - "$USER" -c "ssh-keygen -t rsa -N '' -f $HOME/.ssh/id_rsa" 2>/dev/null; then
        echo "Warning: Failed to generate SSH key"
    fi
fi

if [ -n "${IDEKUBE_AUTHORIZED_KEYS:-}" ]; then
    echo "Importing IDEKUBE_AUTHORIZED_KEYS"
    if echo -n "$IDEKUBE_AUTHORIZED_KEYS" | base64 -d > "$HOME/.ssh/authorized_keys" 2>/dev/null; then
        chmod 600 "$HOME/.ssh/authorized_keys"
        echo "Authorized keys imported successfully"
    else
        echo "Warning: Failed to decode IDEKUBE_AUTHORIZED_KEYS"
        touch "$HOME/.ssh/authorized_keys"
    fi
else
    echo "IDEKUBE_AUTHORIZED_KEYS is not set"
    touch "$HOME/.ssh/authorized_keys"
fi
chown -R "$USER:$USER" "$HOME/.ssh" 2>/dev/null || echo "Warning: Failed to change ownership of .ssh"

# ------------------------------------------------------
# response to IDEKUBE_INGRESS
# ------------------------------------------------------
IDEKUBE_INGRESS_PATH=${IDEKUBE_INGRESS_PATH:-""}

# ------------------------------------------------------
# Modify Nginx Config file according to IDEKUBE_INGRESS
# ------------------------------------------------------
echo "Configuring Nginx for INGRESS_HOST$IDEKUBE_INGRESS_PATH"
if [ -f /etc/nginx/sites-enabled/default ]; then
    sed -i "s|{{ IDEKUBE_INGRESS_PATH }}|$IDEKUBE_INGRESS_PATH|g" /etc/nginx/sites-enabled/default || \
        echo "Warning: Failed to configure Nginx"
    sed -i "s|{{ IDEKUBE_INGRESS_PATH }}|$IDEKUBE_INGRESS_PATH|g" /etc/supervisor/conf.d/supervisord.conf || \
        echo "Warning: Failed to configure Supervisord"
else
    echo "Warning: Nginx config file not found"
fi

# ------------------------------------------------------
# Detect all startup bash scripts and run them
# ------------------------------------------------------
# Find all scripts in /etc/idekube/, sort them by name
if [ -d /etc/idekube/startup.bash/ ]; then
    scripts=$(find /etc/idekube/startup.bash/ -type f -name "*.sh" 2>/dev/null | sort)
    
    # Loop over the scripts and execute them
    if [ -n "$scripts" ]; then
        while IFS= read -r script; do
            if [ -f "$script" ] && [ -x "$script" ]; then
                echo "Executing $script"
                bash "$script" || echo "Warning: $script exited with error code $?"
            fi
        done <<< "$scripts"
    else
        echo "No startup scripts found in /etc/idekube/startup.bash/"
    fi
else
    echo "Startup scripts directory /etc/idekube/startup.bash/ not found"
fi

exec /usr/local/bin/tini -- supervisord -n -c /etc/supervisor/supervisord.conf
