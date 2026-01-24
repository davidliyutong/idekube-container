FROM ubuntu:24.04

ARG QEMU_VERSION=10.2.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
            build-essential \
            ninja-build \
            meson \
            git \
            curl \
            autoconf \
            libtool \
            clang \
            flex \
            bison \
            libsysfs-dev \
            cloud-image-utils \
            libglib2.0-dev \
            libgtk-3-dev \
            libmount-dev \
            libpixman-1-dev \
            libusb-1.0 \
            libslirp-dev \
            python3 \
            python3-pip \
            cloud-image-utils && \
            rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/qemu
RUN curl -L -o "qemu-${QEMU_VERSION}.tar.xz" "https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz" && \
    tar -xf "qemu-${QEMU_VERSION}.tar.xz" --strip-components=1 && \
    rm "qemu-${QEMU_VERSION}.tar.xz" && \
    ./configure --enable-vhost-user --enable-vhost-net --enable-kvm --enable-libusb --enable-opengl --enable-slirp && \
    cd build && \
    make -j$(nproc) && \
    make install && \
    cd ../.. && \
    rm -rf /tmp/qemu

ARG ROOT_DISK_IMAGE_DIR=""
WORKDIR /var/lib/idekube/
COPY .cache/qemu_files/*.fd ./uefi/
COPY artifacts/qemu/configs/* ./configs/
COPY ${ROOT_DISK_IMAGE_DIR} ./images/

WORKDIR /
COPY artifacts/qemu/startup-scripts/* /

ENTRYPOINT [ "/startup.sh" ]