FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-utils \
    libguestfs-tools \
    linux-image-generic \
    gzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# libguestfs appliance needs a readable kernel; Ubuntu ships vmlinuz 0600.
RUN chmod 0644 /boot/vmlinuz-* || true

ENV LIBGUESTFS_BACKEND=direct

COPY convert.sh /usr/local/bin/convert.sh
RUN chmod +x /usr/local/bin/convert.sh

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/convert.sh"]
