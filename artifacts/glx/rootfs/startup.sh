#!/bin/bash

# Remove any existing lock files
rm -f /tmp/.X*-lock
rm -f /tmp/.X11-unix/X*

exec /usr/local/bin/tini -- supervisord -n -c /etc/supervisor/supervisord.conf

# vncserver :1 -geometry 1280x800 -depth 24 -SecurityTypes None
# exec "$@"