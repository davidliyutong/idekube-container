FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    qemu-utils \
    cloud-image-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace