#!/bin/sh
IDEKUBE_RESOLUTION=${IDEKUBE_RESOLUTION:-"1400x900"}
exec /usr/bin/Xvfb :1 -screen 0 "$IDEKUBE_RESOLUTION"x24