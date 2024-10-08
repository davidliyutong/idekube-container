FROM ubuntu:20.04 AS system
# FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu20.04 AS system

# These arguments are passed in via the docker build command
ARG TZ=Asia/Shanghai \
    APT_MIRROR="mirror.sjtu.edu.cn" \
    USE_APT_MIRROR="true" \
    TINI_VERSION=0.19.0 \
    WEBSOCAT_VERSION=1.13.0 \
    CODER_VERSION=4.7.0 \
    VIRTUALGL_VERSION=3.1 \
    TURBOVNC_VERSION=3.1

# Avoid prompts for time zone
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=${TZ}

# Change APT Source
RUN if [ ${USE_APT_MIRROR} != "false" ]; then \
        sed -i s@/archive.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list && \
        sed -i s@/security.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list && \
        sed -i s@/ports.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list; \
    fi;
# built-in packages
RUN apt-get update \
    && apt-get install -y \
    # APT tools
    apt-utils apt-transport-https software-properties-common \
    # Basic tools
    sudo net-tools unzip xz-utils zstd wget curl tree bison jq zsh git htop vim nano gnupg \
    # Service tools
    supervisor nginx openssh-server \
    # build tools
    python3 python3-pip python3-setuptools python3-wheel python3-dev build-essential cmake \
    # fonts
    ttf-ubuntu-font-family ttf-wqy-zenhei \
    && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# tini to fix subreap
RUN wget -q https://github.com/krallin/tini/archive/v${TINI_VERSION}.tar.gz -O v${TINI_VERSION}.tar.gz  \
    && tar zxf v${TINI_VERSION}.tar.gz \
    && export CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"; \
    cd tini-${TINI_VERSION}; cmake . && make && make install \
    && cd ..; rm -r tini-${TINI_VERSION} v${TINI_VERSION}.tar.gz

# Setup the websocat and ssh
RUN arch=$(uname -m); \
    if [ "$arch" = "arm64" ]; then arch="aarch64"; fi; \
    wget -q https://github.com/vi/websocat/releases/download/v${WEBSOCAT_VERSION}/websocat.$arch-unknown-linux-musl -O /usr/local/bin/websocat \
    && chmod +x /usr/local/bin/websocat
RUN mkdir -p /run/sshd && echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Setup the code-server
RUN arch=$(uname -m); \
    if [ "$arch" = "x86_64" ]; then arch="amd64"; fi; \
    if [ "$arch" = "aarch64" ]; then arch="arm64"; fi; \
    wget -q https://github.com/cdr/code-server/releases/download/v${CODER_VERSION}/code-server-${CODER_VERSION}-linux-$arch.tar.gz -O /tmp/code-server.tar.gz \
    && mkdir -p /usr/lib/code-server && tar -zxf /tmp/code-server.tar.gz -C /usr/lib/code-server --strip-components=1 \
    && ln -s /usr/lib/code-server/bin/code-server /usr/local/bin/code-server \
    && rm /tmp/code-server.tar.gz

# Install Miniconda
RUN arch=$(uname -m); \
    if [ "$arch" = "arm64" ]; then arch="aarch64"; fi; \
    wget -q https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-$arch.sh -O /tmp/miniconda.sh \
    && /bin/bash /tmp/miniconda.sh -b -p /opt/miniconda3 \
    && rm /tmp/miniconda.sh
ENV PATH=/opt/miniconda3/bin:$PATH

# Desktop
RUN apt-get update \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
    xvfb xorg xauth x11-xserver-utils libegl1-mesa libglu1-mesa libglu1 libgl1-mesa-glx libglm-dev xfce4 xfce4-goodies xterm \
    dbus-x11 x11-utils alsa-utils mesa-utils libgl1-mesa-dri libxv1 \
    # Firefox
    && apt-get install -y firefox libpci3 \
    && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Install TurboVNC and VirtualGL
RUN	wget -q -O- https://packagecloud.io/dcommander/virtualgl/gpgkey | gpg --dearmor >/etc/apt/trusted.gpg.d/VirtualGL.gpg && \
    wget -q -O- https://packagecloud.io/dcommander/turbovnc/gpgkey |  gpg --dearmor >/etc/apt/trusted.gpg.d/TurboVNC.gpg && \
    wget -q https://raw.githubusercontent.com/VirtualGL/repo/main/VirtualGL.list -O /etc/apt/sources.list.d/TurboVNC.list && \
    wget -q https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.list -O /etc/apt/sources.list.d/VirtualGL.list
RUN	apt-get update && apt-get install virtualgl -y && apt install turbovnc -y \
    && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*
ENV PATH=${PATH}:/opt/VirtualGL/bin:/opt/TurboVNC/bin

# noVNC
COPY third_party/noVNC /var/lib/novnc
COPY third_party/websockify /var/lib/novnc/utils/websockify
# Configure nginx server for container
RUN sed -i 's|worker_processes .*|worker_processes 1;|' /etc/nginx/nginx.conf

# Create the IDEKube user with home and bash shell, set the password to 'idekube'
# Allow 'idekube' to run sudo commands without password by modifying the sudoers file
RUN useradd -m -s /bin/bash idekube \
    && echo "idekube:idekube" | chpasswd \
    && echo "idekube ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo

# Setup the root filesystem
COPY artifacts/coder/rootfs /

# Setting Environment Variables for startup.sh
ENV SHELL=/bin/bash \
    USERNAME=idekube \
    USERID=1000

EXPOSE 80
ENTRYPOINT ["/startup.sh"]
