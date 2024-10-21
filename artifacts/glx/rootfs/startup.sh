#!/bin/bash

# Remove any existing lock files
rm -f /tmp/.X*-lock
rm -f /tmp/.X11-unix/X*

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