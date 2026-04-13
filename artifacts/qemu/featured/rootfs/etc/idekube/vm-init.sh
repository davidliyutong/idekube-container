#!/bin/bash
#
# vm-init.sh — Runtime initialization for IDEKube QEMU VMs.
# Called by cloud-init runcmd after boot.
#
# Reads /etc/idekube/runtime-env (written by cloud-init write_files)
# and applies runtime configuration: UID remapping, SSH authorized keys,
# preferred shell, SSH password auth lockdown, and startup hooks.
#

USER=idekube
HOME=/home/${USER}

# Source runtime environment if available
if [ -f /etc/idekube/runtime-env ]; then
    . /etc/idekube/runtime-env
fi

# ------------------------------------------------------
# UID remapping
# ------------------------------------------------------
if [ -n "${IDEKUBE_USER_UID:-}" ]; then
    CURRENT_UID=$(id -u "$USER" 2>/dev/null)
    if [ "$CURRENT_UID" != "$IDEKUBE_USER_UID" ]; then
        echo "vm-init: Changing UID of $USER from $CURRENT_UID to $IDEKUBE_USER_UID"
        if usermod -u "$IDEKUBE_USER_UID" "$USER" 2>/dev/null; then
            echo "vm-init: UID changed successfully"
            if [ -d "$HOME" ]; then
                chown -R "$USER:$USER" "$HOME" 2>/dev/null || echo "vm-init: Warning: Failed to update home ownership after UID change"
            fi
        else
            echo "vm-init: Warning: Failed to change UID for $USER"
        fi
    else
        echo "vm-init: UID of $USER is already $IDEKUBE_USER_UID"
    fi
fi

# ------------------------------------------------------
# Home folder ownership
# ------------------------------------------------------
if [ -d "$HOME" ]; then
    current_owner=$(stat -c '%U' "$HOME" 2>/dev/null)
    if [ "$current_owner" != "$USER" ]; then
        echo "vm-init: Fixing home folder ownership"
        chown -R "$USER:$USER" "$HOME" 2>/dev/null || echo "vm-init: Warning: Failed to fix home ownership"
    fi
fi
chmod 755 "$HOME" 2>/dev/null || true

# ------------------------------------------------------
# Home initialization
# ------------------------------------------------------
home_contents=$(ls -A "$HOME" 2>/dev/null | grep -v '^lost+found$' || true)
if [ -n "${IDEKUBE_INIT_HOME:-}" ] || [ -z "$home_contents" ]; then
    echo "vm-init: Initializing home folder from /etc/skel"
    if [ -d /etc/skel ]; then
        rsync -al /etc/skel/ "$HOME/" 2>/dev/null || echo "vm-init: Warning: Failed to sync skel"
        chown -R "$USER:$USER" "$HOME" 2>/dev/null || true
    fi
fi

# ------------------------------------------------------
# SSH authorized keys
# ------------------------------------------------------
if [ ! -d "$HOME/.ssh" ]; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t rsa -N '' -f "$HOME/.ssh/id_rsa" -q 2>/dev/null || echo "vm-init: Warning: Failed to generate SSH key"
    chown -R "$USER:$USER" "$HOME/.ssh"
fi

if [ -n "${IDEKUBE_AUTHORIZED_KEYS:-}" ]; then
    echo "vm-init: Importing IDEKUBE_AUTHORIZED_KEYS"
    if echo -n "$IDEKUBE_AUTHORIZED_KEYS" | base64 -d > "$HOME/.ssh/authorized_keys" 2>/dev/null; then
        chmod 600 "$HOME/.ssh/authorized_keys"
        echo "vm-init: Authorized keys imported successfully"
    else
        echo "vm-init: Warning: Failed to decode IDEKUBE_AUTHORIZED_KEYS"
        touch "$HOME/.ssh/authorized_keys"
    fi
else
    touch "$HOME/.ssh/authorized_keys"
fi
chown -R "$USER:$USER" "$HOME/.ssh" 2>/dev/null || true

# ------------------------------------------------------
# Preferred shell
# ------------------------------------------------------
IDEKUBE_PREFERED_SHELL="${IDEKUBE_PREFERED_SHELL:-/bin/bash}"
if [ -f "$IDEKUBE_PREFERED_SHELL" ]; then
    echo "vm-init: Setting shell to $IDEKUBE_PREFERED_SHELL"
    usermod -s "$IDEKUBE_PREFERED_SHELL" "$USER" 2>/dev/null || echo "vm-init: Warning: Failed to change shell"
fi

# ------------------------------------------------------
# Disable SSH password authentication
# ------------------------------------------------------
echo "vm-init: Disabling SSH password authentication"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
# Also handle Include'd config fragments
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
            if [ -f "$script" ]; then
                echo "vm-init: Executing $script"
                bash "$script" || echo "vm-init: Warning: $script exited with error code $?"
            fi
        done <<< "$scripts"
    else
        echo "vm-init: No startup scripts found in /etc/idekube/startup.bash/"
    fi
fi

# ------------------------------------------------------
# Restart nginx to pick up access_token.conf changes
# ------------------------------------------------------
echo "vm-init: Restarting nginx"
systemctl restart nginx 2>/dev/null || true

echo "vm-init: Initialization complete"
