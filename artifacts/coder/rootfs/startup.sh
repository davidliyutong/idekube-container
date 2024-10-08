#!/bin/bash

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
IDEKUBE_INIT_HOME=${IDEKUBE_INIT_HOME:-"false"}
if $IDEKUBE_INIT_HOME; then
    echo "Initializing home folder"
    rsync -r /usr/local/share/home_template/*. $HOME/
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
if [ -z "$IDEKUBE_INGRESS_HOST" ]; then
    IDEKUBE_INGRESS_HOST="localhost"
fi
if [ -z "$IDEKUBE_INGRESS_PATH" ]; then
    IDEKUBE_INGRESS_PATH=""
fi
if [ -z "$IDEKUBE_INGRESS_SCHEME" ]; then
    IDEKUBE_INGRESS_SCHEME="http"
fi

# ------------------------------------------------------
# Modify Nginx Config file according to IDEKUBE_INGRESS
# ------------------------------------------------------
echo "Configuring Nginx for $IDEKUBE_INGRESS_SCHEME://$IDEKUBE_INGRESS_HOST$IDEKUBE_INGRESS_PATH"
sed -i "s|{{ IDEKUBE_INGRESS_HOST }}|$IDEKUBE_INGRESS_HOST|g" /etc/nginx/sites-enabled/default
sed -i "s|{{ IDEKUBE_INGRESS_PATH }}|$IDEKUBE_INGRESS_PATH|g" /etc/nginx/sites-enabled/default

# ------------------------------------------------------
# Modify supervisord config file according to IDEKUBE_INGRESS
# ------------------------------------------------------
echo "Configuring Supervisord for $IDEKUBE_INGRESS_SCHEME://$IDEKUBE_INGRESS_HOST$IDEKUBE_INGRESS_PATH"
sed -i "s|{{ IDEKUBE_INGRESS_HOST }}|$IDEKUBE_INGRESS_HOST|g" /etc/supervisor/supervisord.conf
sed -i "s|{{ IDEKUBE_INGRESS_PATH }}|$IDEKUBE_INGRESS_PATH|g" /etc/supervisor/supervisord.conf
sed -i "s|{{ IDEKUBE_INGRESS_SCHEME }}|$IDEKUBE_INGRESS_SCHEME|g" /etc/supervisor/supervisord.conf


# ------------------------------------------------------
# Modify /var/lib/novnc/index.html according to IDEKUBE_INGRESS
# ------------------------------------------------------
echo "Configuring noVNC for $IDEKUBE_INGRESS_SCHEME://$IDEKUBE_INGRESS_HOST$IDEKUBE_INGRESS_PATH"
sed -i "s|{{ IDEKUBE_INGRESS_PATH }}|$IDEKUBE_INGRESS_PATH|g" /var/lib/novnc/index.html

exec /usr/local/bin/tini -- supervisord -n -c /etc/supervisor/supervisord.conf
