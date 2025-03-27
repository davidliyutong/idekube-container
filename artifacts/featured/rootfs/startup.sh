#!/bin/bash

# check if I_AM_INIT_CONTAINER is set
if [ -z "$I_AM_INIT_CONTAINER" ]; then
  echo "I_AM_INIT_CONTAINER variable is not set. Skipping..."
else
  echo "I_AM_INIT_CONTAINER variable is set."
  bash /init-container.sh
  exit $?
fi

USER=${USERNAME:-root}
if [ "$USER" != "root" ]; then
    HOME=/home/$USER
else
    HOME=/root
fi

# Remove any existing lock files
rm -f /tmp/.X*-lock
rm -f /tmp/.X11-unix/X*

# ------------------------------------------------------
# response to IDEKUBE_PREFERED_SHELL
# ------------------------------------------------------
IDEKUBE_PREFERED_SHELL=${IDEKUBE_PREFERED_SHELL:-"/bin/bash"}
if [ -f $IDEKUBE_PREFERED_SHELL ]; then
    echo "Setting shell to $IDEKUBE_PREFERED_SHELL"
    usermod -s $IDEKUBE_PREFERED_SHELL $USER
else
    echo "Shell $IDEKUBE_PREFERED_SHELL not found"
fi

# ------------------------------------------------------
# response to IDEKUBE_INIT_HOME
# ------------------------------------------------------
if [ ! -z "$IDEKUBE_INIT_HOME" ]; then
    echo "Initializing home folder"
    rsync -r /etc/skel/ $HOME/
    chown -R $USER:$USER $HOME
else
    echo "Skipping home folder initialization"
fi

# ------------------------------------------------------
# response to IDEKUBE_AUTHORIZED_KEYS
# ------------------------------------------------------
if [ ! -d "$HOME/.ssh" ]; then
    su - $USER -c "ssh-keygen -t rsa -N '' -f $HOME/.ssh/id_rsa"
fi
if [ ! -z "$IDEKUBE_AUTHORIZED_KEYS" ]; then
    echo "Importing IDEKUBE_AUTHORIZED_KEYS"
    echo "$IDEKUBE_AUTHORIZED_KEYS" | base64 -d >$HOME/.ssh/authorized_keys
else
    echo "IDEKUBE_AUTHORIZED_KEYS is not set"
    touch $HOME/.ssh/authorized_keys
fi
chown -R $USER:$USER $HOME/.ssh/authorized_keys

# ------------------------------------------------------
# response to IDEKUBE_INGRESS
# ------------------------------------------------------
IDEKUBE_INGRESS_PATH=${IDEKUBE_INGRESS_PATH:-""}

# ------------------------------------------------------
# Modify Nginx Config file according to IDEKUBE_INGRESS
# ------------------------------------------------------
echo "Configuring Nginx for INGRESS_HOST$IDEKUBE_INGRESS_PATH"
sed -i "s|{{ IDEKUBE_INGRESS_PATH }}|$IDEKUBE_INGRESS_PATH|g" /etc/nginx/sites-enabled/default

# ------------------------------------------------------
# Detect all startup bash scripts and run them
# ------------------------------------------------------
# Find all scripts in /etc/idekube/, sort them by name
scripts=$(find /etc/idekube/startup.bash/ -type f -name "*.sh" | sort)

# Loop over the scripts and execute them
for script in $scripts
do
    echo "Executing $script"
    bash $script
done

exec /usr/local/bin/tini -- supervisord -n -c /etc/supervisor/supervisord.conf
