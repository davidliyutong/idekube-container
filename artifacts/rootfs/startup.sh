#!/bin/bash

USER=${USERNAME:-root}
if [ "$USER" != "root" ]; then
    HOME=/home/$USER
else
    HOME=/root
fi

# home folder
if [ ! -d "$HOME/.config/pcmanfm/LXDE/" ]; then
    mkdir -p $HOME/.config/pcmanfm/LXDE/
    ln -sf /usr/local/share/doro-lxde-wallpapers/desktop-items-0.conf $HOME/.config/pcmanfm/LXDE/
    chown -R $USER:$USER $HOME
fi

exec /usr/local/bin/tini -- supervisord -n -c /etc/supervisor/supervisord.conf