#FROM ubuntu:20.04 AS system
FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu20.04 AS system

# These arguments are passed in via the docker build command
ARG TZ=Asia/Shanghai \
    APT_MIRROR="mirror.sjtu.edu.cn" \
    TINI_VERSION=0.19.0 \
    WEBSOCAT_VERSION=1.13.0 \
    CODER_VERSION=4.7.0 \
    VIRTUALGL_VERSION=3.1 \
    TURBOVNC_VERSION=3.1

# Avoid prompts for time zone
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=${TZ}

# Change APT Source
RUN sed -i s@/archive.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list && \
    sed -i s@/security.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list && \
    sed -i s@/ports.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list

# built-in packages
RUN apt-get update \
    && apt-get install -y wget curl vim build-essential cmake supervisor \
    && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# tini to fix subreap
RUN wget https://github.com/krallin/tini/archive/v${TINI_VERSION}.tar.gz -O v${TINI_VERSION}.tar.gz  \
    && tar zxf v${TINI_VERSION}.tar.gz \
    && export CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"; \
    cd tini-${TINI_VERSION}; cmake . && make && make install \
    && cd ..; rm -r tini-${TINI_VERSION} v${TINI_VERSION}.tar.gz

# Desktop
RUN apt-get update \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
    xorg xauth x11-xserver-utils libegl1-mesa libgl1-mesa-glx libglm-dev xfce4 xfce4-goodies xterm \
    # Firefox
    && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Install TurboVNC and VirtualGL
RUN wget -O /tmp/virtualgl_${VIRTUALGL_VERSION}_amd64.deb https://sourceforge.net/projects/virtualgl/files/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_amd64.deb/download && \
    wget -O /tmp/turbovnc_${TURBOVNC_VERSION}_amd64.deb https://sourceforge.net/projects/turbovnc/files/${TURBOVNC_VERSION}/turbovnc_${TURBOVNC_VERSION}_amd64.deb/download && \
    dpkg -i /tmp/virtualgl_${VIRTUALGL_VERSION}_amd64.deb && \
    dpkg -i /tmp/turbovnc_${TURBOVNC_VERSION}_amd64.deb && \
    rm -rf /tmp/*.deb
ENV PATH=${PATH}:/opt/VirtualGL/bin:/opt/TurboVNC/bin

# Setup the root filesystem
COPY artifacts/glx/rootfs /

ENTRYPOINT ["/startup.sh"]
CMD ["/bin/bash"]