#!/bin/bash
set -e

add-apt-repository ppa:xtradeb/apps
apt-get update
apt-get install -y  --no-install-recommends chromium
apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*
update-alternatives --set x-www-browser /usr/bin/chromium