#!/bin/bash

USER=${USERNAME:-root}
if [ "$USER" != "root" ]; then
    HOME=/home/$USER
else
    HOME=/root
fi

# home folder configuration
if [ ! -d "$HOME/.config/pcmanfm/LXDE/" ]; then
    mkdir -p $HOME/.config/pcmanfm/LXDE/
    ln -sf /usr/local/share/doro-lxde-wallpapers/desktop-items-0.conf $HOME/.config/pcmanfm/LXDE/
    chown -R $USER:$USER $HOME
fi

# ------------------------------------------------------
# response to IDEKUBE_AUTHORIZED_KEYS
# ------------------------------------------------------
if [ ! -d "$HOME/.ssh" ]; then
    su - $USER -c "ssh-keygen -t rsa -N '' -f $HOME/.ssh/id_rsa"
fi
if [ ! -z "$IDEKUBE_AUTHORIZED_KEYS" ]; then
    echo "Importing IDEKUBE_AUTHORIZED_KEYS"
    echo "$IDEKUBE_AUTHORIZED_KEYS" | base64 -d > $HOME/.ssh/authorized_keys
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
sed -i "s|{{ IDEKUBE_INGRESS_HOST }}|$IDEKUBE_INGRESS_HOST|g" /etc/nginx/sites-enabled/default
sed -i "s|{{ IDEKUBE_INGRESS_PATH }}|$IDEKUBE_INGRESS_PATH|g" /etc/nginx/sites-enabled/default

# ------------------------------------------------------
# Modify supervisord config file according to IDEKUBE_INGRESS
# ------------------------------------------------------
sed -i "s|{{ IDEKUBE_INGRESS_HOST }}|$IDEKUBE_INGRESS_HOST|g" /etc/supervisor/supervisord.conf
sed -i "s|{{ IDEKUBE_INGRESS_PATH }}|$IDEKUBE_INGRESS_PATH|g" /etc/supervisor/supervisord.conf
sed -i "s|{{ IDEKUBE_INGRESS_SCHEME }}|$IDEKUBE_INGRESS_SCHEME|g" /etc/supervisor/supervisord.conf

exec /usr/local/bin/tini -- supervisord -n -c /etc/supervisor/supervisord.conf