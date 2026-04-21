#!/bin/bash
# Thin wrapper that picks the right TurboVNC flags based on whether a
# 3D-capable GPU is visible to this user. On GPU hosts we enable -vgl so
# VirtualGL uses the optimized transport to Xvnc; on GPU-less hosts we run
# plain vncserver. All other args are passed through unchanged.
set -u

gpu=0
for node in /dev/dri/renderD*; do
  [ -r "$node" ] && gpu=1 && break
done

extra=()
if [ "$gpu" = 1 ] && command -v vglrun >/dev/null 2>&1; then
  echo "turbovnc-launch: GPU render node readable + vglrun present -> enabling -vgl"
  extra=(-vgl)
else
  echo "turbovnc-launch: no usable GPU render node -> running without -vgl"
fi

exec /opt/TurboVNC/bin/vncserver "${extra[@]}" "$@"