#!/bin/bash
set -e

apt-get update 
apt-get install -y  --no-install-recommends --allow-unauthenticated \
    xfce4 xfce4-goodies xterm dbus-x11 \
    xvfb xorg xauth x11-xserver-utils libglu1-mesa libglu1 libgl1 libglm-dev  \
    x11-utils alsa-utils mesa-utils libgl1-mesa-dri libxv1 \
    fonts-wqy-zenhei
apt-get remove -y xfce4-screensaver --purge
apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*