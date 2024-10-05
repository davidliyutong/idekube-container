FROM ubuntu:20.04 AS system

# These arguments are passed in via the docker build command
ARG TZ=Asia/Shanghai
ARG ARCH=amd64
ARG MACHINE=x86_64

# Avoid prompts for time zone
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=${TZ}
# Fix issue with libGL on Windows
ENV LIBGL_ALWAYS_INDIRECT=1

# Change APT Source
ARG APT_MIRROR="mirror.sjtu.edu.cn"
RUN sed -i s@/archive.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list && \
    sed -i s@/security.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list && \
    sed -i s@/ports.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list

# built-in packages
RUN apt-get update && apt-get install -y apt-utils wget curl jq zsh git htop vim nano -y \
    && apt-get install -y --no-install-recommends --allow-unauthenticated supervisor sudo net-tools zenity xz-utils nginx \
    dbus-x11 x11-utils alsa-utils mesa-utils libgl1-mesa-dri libegl1-mesa libglu1-mesa libglu1 libxv1 libglm-dev \
    # build tools
    python3 python3-pip python3-setuptools python3-wheel python3-dev build-essential cmake \
    # fonts
    ttf-ubuntu-font-family ttf-wqy-zenhei \
    # Desktop
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
    gtk2-engines-murrine gtk2-engines-pixbuf gtk2-engines-murrine arc-theme \
    # Firefox
    && apt-get install -y firefox libpci3 \
    # OpenSSH
    && apt-get install -y openssh-server \
    && apt-get autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# tini to fix subreap
ARG TINI_VERSION=0.19.0
RUN wget https://github.com/krallin/tini/archive/v${TINI_VERSION}.tar.gz -O v${TINI_VERSION}.tar.gz  \
    && tar zxf v${TINI_VERSION}.tar.gz \
    && export CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"; \
    cd tini-${TINI_VERSION}; cmake . && make && make install \
    && cd ..; rm -r tini-${TINI_VERSION} v${TINI_VERSION}.tar.gz

# Install TurboVNC and VirtualGL
RUN apt-get update && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    gnupg apt-transport-https software-properties-common xvfb x11vnc xauth xorg tightvncserver xauth xfce4 xfce4-goodies
RUN	wget -q -O- https://packagecloud.io/dcommander/virtualgl/gpgkey | gpg --dearmor >/etc/apt/trusted.gpg.d/VirtualGL.gpg && \
    wget -q -O- https://packagecloud.io/dcommander/turbovnc/gpgkey |  gpg --dearmor >/etc/apt/trusted.gpg.d/TurboVNC.gpg && \
    wget https://raw.githubusercontent.com/VirtualGL/repo/main/VirtualGL.list -O /etc/apt/sources.list.d/TurboVNC.list && \
    wget https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.list -O /etc/apt/sources.list.d/VirtualGL.list
RUN	apt-get update && \
    apt-get install virtualgl -y && \
    apt install turbovnc -y
ENV PATH=${PATH}:/opt/VirtualGL/bin:/opt/TurboVNC/bin
ENV VGL_DISPLAY=:1

# noVNC
COPY third_party/noVNC /var/lib/novnc
COPY third_party/websockify /var/lib/novnc/utils/websockify

# Setup the websocat and ssh
ARG WEBSOCAT_VERSION=1.13.0
RUN wget https://github.com/vi/websocat/releases/download/v${WEBSOCAT_VERSION}/websocat.${MACHINE}-unknown-linux-musl -O /usr/local/bin/websocat \
    && chmod +x /usr/local/bin/websocat
RUN mkdir -p /run/sshd && echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Setup the code-server
ARG CODER_VERSION=4.7.0
RUN wget https://github.com/cdr/code-server/releases/download/v${CODER_VERSION}/code-server-${CODER_VERSION}-linux-${ARCH}.tar.gz -O /tmp/code-server.tar.gz \
    && mkdir -p /usr/lib/code-server && tar -zxf /tmp/code-server.tar.gz -C /usr/lib/code-server --strip-components=1 \
    && ln -s /usr/lib/code-server/bin/code-server /usr/local/bin/code-server \
    && rm /tmp/code-server.tar.gz


# Create the IDEKube user with home and bash shell, set the password to 'idekube'
# Allow 'idekube' to run sudo commands without password by modifying the sudoers file
RUN useradd -m -s /bin/bash idekube \
    && echo "idekube:idekube" | chpasswd \
    && echo "idekube ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo

# Install Miniconda
RUN wget --quiet https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-${MACHINE}.sh -O /tmp/miniconda.sh \
    && /bin/bash /tmp/miniconda.sh -b -p /opt/miniconda3 \
    && rm /tmp/miniconda.sh
ENV PATH=/opt/miniconda3/bin:$PATH

# Configure nginx server for noVNC
# nginx workers
RUN sed -i 's|worker_processes .*|worker_processes 1;|' /etc/nginx/nginx.conf

# Setup the root filesystem
COPY artifacts/coder/rootfs /

# Setting Environment Variables for startup.sh
ENV SHELL=/bin/bash \
    USERNAME=idekube \
    USERID=1000

EXPOSE 80
ENTRYPOINT ["/startup.sh"]