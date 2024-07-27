FROM ubuntu:20.04 as system

# These arguments are passed in via the docker build command
ARG TZ=Asia/Shanghai
ARG ARCH=amd64
ARG MACHINE=x86_64
ARG MACHINE_ALIAS=amd64

# Avoid prompts for time zone
ENV DEBIAN_FRONTEND noninteractive
ENV TZ=${TZ}
# Fix issue with libGL on Windows
ENV LIBGL_ALWAYS_INDIRECT=1

# Change APT Source
RUN sed -i s@/archive.ubuntu.com/@/mirror.sjtu.edu.cn/@g /etc/apt/sources.list && \
    sed -i s@/security.ubuntu.com/@/mirror.sjtu.edu.cn/@g /etc/apt/sources.list && \
    sed -i s@/ports.ubuntu.com/@/mirror.sjtu.edu.cn/@g /etc/apt/sources.list

# built-in packages
RUN apt-get update && apt-get install apt-utils -y \
    && apt-get install -y --no-install-recommends --allow-unauthenticated wget curl vim jq \
    supervisor sudo net-tools zenity xz-utils \
    dbus-x11 x11-utils alsa-utils mesa-utils libgl1-mesa-dri libegl1-mesa libglu1-mesa libglu1 libxv1 \
    python3 python3-pip python3-setuptools python3-wheel python3-dev build-essential cmake \
    # x11vnc
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
    xvfb x11vnc xauth \
    ttf-ubuntu-font-family ttf-wqy-zenhei \
    # Desktop
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
    lxde gtk2-engines-murrine gnome-themes-standard gtk2-engines-pixbuf gtk2-engines-murrine arc-theme \
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
ARG SOURCEFORGE=https://sourceforge.net/projects
ARG TURBOVNC_VERSION=3.0.3
ARG VIRTUALGL_VERSION=3.0.1
ARG LIBJPEG_VERSION=3.0.1
RUN mkdir /tmp/turbovnc/ && cd /tmp/turbovnc\
    && curl -fsSL -O ${SOURCEFORGE}/turbovnc/files/${TURBOVNC_VERSION}/turbovnc_${TURBOVNC_VERSION}_${ARCH}.deb \
    -O ${SOURCEFORGE}/libjpeg-turbo/files/${LIBJPEG_VERSION}/libjpeg-turbo-official_${LIBJPEG_VERSION}_${ARCH}.deb \
    -O ${SOURCEFORGE}/virtualgl/files/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_${ARCH}.deb \
    && dpkg -i *.deb \
    && rm -rf /tmp/turbovnc \
    && sed -i 's/$host:/unix:/g' /opt/TurboVNC/bin/vncserver
ENV PATH ${PATH}:/opt/VirtualGL/bin:/opt/TurboVNC/bin
ENV VGL_DISPLAY=:1

# noVNC
COPY third_party/noVNC /var/lib/novnc
COPY third_party/websockify /var/lib/novnc/utils/websockify

# Setup the websocat and ssh
ARG WEBSOCAT_VERSION=1.13.0
RUN (wget https://github.com/vi/websocat/releases/download/v${WEBSOCAT_VERSION}/websocat.${MACHINE}-unknown-linux-musl -O /usr/local/bin/websocat \
    || wget https://github.com/vi/websocat/releases/download/v${WEBSOCAT_VERSION}/websocat.${MACHINE_ALIAS}-unknown-linux-musl -O /usr/local/bin/websocat) \
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
RUN wget --quiet https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh \
    && /bin/bash /tmp/miniconda.sh -b -p /opt/miniconda3 \
    && rm /tmp/miniconda.sh


# Setup the root filesystem
COPY artifacts/rootfs /


# Setting Environment Variables for startup.sh
ENV SHELL=/bin/bash \
    USERNAME=idekube \
    USERID=1000

EXPOSE 3000 80 2222
ENTRYPOINT ["/startup.sh"]