#!/bin/bash
set -e

# Add the GPG keys for VirtualGL and TurboVNC
wget -q -O- https://packagecloud.io/dcommander/virtualgl/gpgkey | gpg --dearmor >/etc/apt/trusted.gpg.d/VirtualGL.gpg
wget -q -O- https://packagecloud.io/dcommander/turbovnc/gpgkey | gpg --dearmor >/etc/apt/trusted.gpg.d/TurboVNC.gpg

# Add the package repositories for VirtualGL and TurboVNC
wget -q https://raw.githubusercontent.com/VirtualGL/repo/main/VirtualGL.list -O /etc/apt/sources.list.d/VirtualGL.list
wget -q https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.list -O /etc/apt/sources.list.d/TurboVNC.list

# Update the package lists and install VirtualGL and TurboVNC
apt-get update
apt-get install -y virtualgl turbovnc

# Clean up
apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# FIXME: This is a workaround for a bug in the TurboVNC package
ln -s /usr/share/xsessions/xfce.desktop /usr/share/xsessions/ubuntu.desktop