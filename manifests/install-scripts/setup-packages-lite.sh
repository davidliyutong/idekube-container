#!/bin/bash
set -e

apt-get update 
apt-get install -y --no-install-recommends apt-utils apt-transport-https software-properties-common \
    sudo wget curl git htop vim gnupg rsync tmux \
    supervisor nginx openssh-server proot \
    python3 python3-pip
apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Limit the number of worker processes in Nginx
sed -i 's|worker_processes .*|worker_processes 2;|' /etc/nginx/nginx.conf