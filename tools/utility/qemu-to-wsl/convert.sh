#!/usr/bin/env bash
# Converts a qcow2 VM disk (mounted at /workspace/root.img) into a
# WSL2-importable rootfs tarball at /workspace/out/wsl-rootfs.tar.gz.
set -euo pipefail

IN="${IN:-/workspace/root.img}"
OUT="${OUT:-/workspace/out/wsl-rootfs.tar.gz}"
WORK="/tmp/work.img"

if [[ ! -f "$IN" ]]; then
    echo "error: input disk not found at $IN" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUT")"

echo "[1/4] Copying qcow2 to writable scratch..."
cp "$IN" "$WORK"

echo "[2/4] Applying WSL-specific tweaks via guestfish..."
guestfish --rw -a "$WORK" -i <<'EOF'
# Write WSL config so systemd runs and resolv.conf is managed by WSL.
write /etc/wsl.conf "[boot]\nsystemd=true\n\n[network]\ngenerateResolvConf=true\n"

# fstab has UUIDs for the VM's ESP / root partition — WSL can't honor them.
write /etc/fstab "# Managed by WSL; original entries removed during qemu-to-wsl export.\n"

# Force a fresh machine-id on first WSL boot.
write /etc/machine-id ""

# Delete SSH host keys so each imported distro regenerates its own.
glob rm-f /etc/ssh/ssh_host_*

# cloud-init is the QEMU boot path; disable it under WSL.
mkdir-p /etc/cloud
touch /etc/cloud/cloud-init.disabled
EOF

echo "[3/4] Streaming rootfs tarball via virt-tar-out..."
virt-tar-out -a "$WORK" / - | gzip -c > "$OUT"

echo "[4/4] Fixing output ownership (HOST_UID=${HOST_UID:-0}, HOST_GID=${HOST_GID:-0})..."
if [[ -n "${HOST_UID:-}" && -n "${HOST_GID:-}" ]]; then
    chown "${HOST_UID}:${HOST_GID}" "$OUT"
fi

SIZE=$(du -h "$OUT" | cut -f1)
echo ""
echo "✓ Wrote ${OUT} (${SIZE})"
