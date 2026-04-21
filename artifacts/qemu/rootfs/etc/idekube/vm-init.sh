#!/bin/bash
#
# vm-init.sh — Runtime initialization for IDEKube QEMU VMs.
# Called by cloud-init runcmd on first boot.
#
# Reads /etc/idekube/runtime-env (written by cloud-init write_files from the
# container's IDEKUBE_* environment variables) and applies the same runtime
# configuration as artifacts/docker/rootfs/startup.sh does for native images:
# UID remapping, preferred shell, home init, SSH authorized keys, nginx
# access-token auth, SSH password lockdown, and startup hooks.
#

USER=idekube
HOME=/home/${USER}

# Source runtime environment injected by cloud-init.
# set -a / set +a auto-exports every variable assigned during the source so
# that child processes (e.g. bash /authn.sh) inherit them, matching the
# behaviour of Docker containers where IDEKUBE_* vars are already exported.
if [ -f /etc/idekube/runtime-env ]; then
    set -a
    . /etc/idekube/runtime-env
    set +a
fi

# ------------------------------------------------------
# UID remapping
# ------------------------------------------------------
if [ -n "${IDEKUBE_USER_UID:-}" ]; then
    CURRENT_UID=$(id -u "$USER" 2>/dev/null)
    if [ "$CURRENT_UID" != "$IDEKUBE_USER_UID" ]; then
        echo "Changing UID of $USER from $CURRENT_UID to $IDEKUBE_USER_UID"
        if usermod -u "$IDEKUBE_USER_UID" "$USER" 2>/dev/null; then
            echo "UID changed successfully"
            if [ -d "$HOME" ]; then
                chown -R "$USER:$USER" "$HOME" 2>/dev/null || echo "Warning: Failed to update home ownership after UID change"
            fi
        else
            echo "Warning: Failed to change UID for $USER"
        fi
    else
        echo "UID of $USER is already $IDEKUBE_USER_UID"
    fi
fi

# Remove any existing X lock files (left over if VM was not cleanly shut down)
rm -f /tmp/.X*-lock 2>/dev/null || true
rm -f /tmp/.X11-unix/X* 2>/dev/null || true

# ------------------------------------------------------
# Preferred shell
# ------------------------------------------------------
IDEKUBE_PREFERED_SHELL="${IDEKUBE_PREFERED_SHELL:-/bin/bash}"
if [ -f "$IDEKUBE_PREFERED_SHELL" ]; then
    echo "Setting shell to $IDEKUBE_PREFERED_SHELL"
    if usermod -s "$IDEKUBE_PREFERED_SHELL" "$USER" 2>/dev/null; then
        echo "Shell changed successfully"
    else
        echo "Warning: Failed to change shell for $USER"
    fi
else
    echo "Shell $IDEKUBE_PREFERED_SHELL not found, keeping default"
fi

# ------------------------------------------------------
# Ensure home folder is owned by user
# ------------------------------------------------------
if [ -d "$HOME" ]; then
    current_owner=$(stat -c '%U' "$HOME" 2>/dev/null)
    if [ "$current_owner" != "$USER" ]; then
        echo "Home folder ownership mismatch. Current owner: $current_owner, Expected: $USER"
        echo "Fixing home folder ownership"
        if chown -R "$USER:$USER" "$HOME" 2>/dev/null; then
            echo "Home folder ownership fixed successfully"
        else
            echo "Warning: Failed to fix home folder ownership"
        fi
    else
        echo "Home folder is correctly owned by $USER"
    fi
else
    echo "Warning: Home folder $HOME does not exist"
fi
chmod 755 "$HOME" 2>/dev/null || echo "Warning: Failed to set permissions on home folder"

# ------------------------------------------------------
# Home initialization
# ------------------------------------------------------
home_contents=$(ls -A "$HOME" 2>/dev/null | grep -v '^lost+found$' || true)
if [ -n "${IDEKUBE_INIT_HOME:-}" ] || [ -z "$home_contents" ]; then
    echo "Initializing home folder"
    if [ -d /etc/skel ]; then
        rsync -al /etc/skel/ "$HOME/" 2>/dev/null || echo "Warning: Failed to sync skel to home"
        chown -R "$USER:$USER" "$HOME" 2>/dev/null || echo "Warning: Failed to change ownership of home"
    else
        echo "Warning: /etc/skel directory not found"
    fi
else
    echo "Skipping home folder initialization"
fi

# ------------------------------------------------------
# SSH authorized keys
# ------------------------------------------------------
if [ ! -d "$HOME/.ssh" ]; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    if ! ssh-keygen -t rsa -N '' -f "$HOME/.ssh/id_rsa" -q 2>/dev/null; then
        echo "Warning: Failed to generate SSH key"
    fi
    chown -R "$USER:$USER" "$HOME/.ssh"
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
# Access token auth (nginx)
# ------------------------------------------------------
bash /authn.sh

# ------------------------------------------------------
# Disable SSH password authentication
# ------------------------------------------------------
echo "Disabling SSH password authentication"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
if [ -d /etc/ssh/sshd_config.d ]; then
    for f in /etc/ssh/sshd_config.d/*.conf; do
        [ -f "$f" ] && sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$f"
    done
fi
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true

# ------------------------------------------------------
# Startup hooks
# ------------------------------------------------------
if [ -d /etc/idekube/startup.bash/ ]; then
    scripts=$(find /etc/idekube/startup.bash/ -type f -name "*.sh" 2>/dev/null | sort)
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

# ------------------------------------------------------
# Restart nginx to pick up access_token.conf changes
# ------------------------------------------------------
echo "Restarting nginx"
systemctl restart nginx 2>/dev/null || true

echo "Initialization complete"
