FROM ubuntu:24.04 AS system
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

# Copy the install scripts
COPY manifests/install-scripts/ /tmp/install-scripts/

# Change APT Source
RUN if [ ${USE_APT_MIRROR} != "false" ]; then \
        sed -i s@/archive.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list && \
        sed -i s@/security.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list && \
        sed -i s@/ports.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list; \
    fi;

# built-in packages
RUN bash /tmp/install-scripts/setup-packages.sh

# tini to fix subreap
RUN export TINI_VERSION=${TINI_VERSION}; bash /tmp/install-scripts/setup-tini.sh

# Setup the websocat and ssh
RUN export WEBSOCAT_VERSION=${WEBSOCAT_VERSION}; bash /tmp/install-scripts/setup-websocat-ssh.sh

# Setup the code-server
RUN export CODER_VERSION=${CODER_VERSION}; bash /tmp/install-scripts/setup-code-server.sh

# Install Miniconda
RUN bash /tmp/install-scripts/setup-miniconda.sh
ENV PATH=/opt/miniconda3/bin:$PATH

# Setup VGL
RUN bash /tmp/install-scripts/setup-vgl.sh
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all

# Desktop
RUN bash /tmp/install-scripts/setup-desktop.sh

# Install the Chromium with ppa:xtradeb/apps
RUN bash /tmp/install-scripts/setup-chromium.sh

# Install TurboVNC and VirtualGL, must done after the desktop
RUN	bash /tmp/install-scripts/setup-vnc.sh
ENV PATH=$PATH:/opt/VirtualGL/bin:/opt/TurboVNC/bin \
    VGL_DISPLAY=egl \
    VNC_THREADS=2 \
    LD_PRELOAD=/usr/lib/libdlfaker.so:/usr/lib/libvglfaker.so

# noVNC
COPY third_party/noVNC /var/lib/novnc
COPY third_party/websockify /var/lib/novnc/utils/websockify

# Create the IDEKube user with home and bash shell
RUN bash /tmp/install-scripts/setup-user.sh
ENV SHELL=/bin/bash \
    USERNAME=idekube \
    USERID=1000

# Setup the root filesystem
COPY artifacts/featured/rootfs /
COPY artifacts/startup-scripts /

EXPOSE 80
ENTRYPOINT ["/startup.sh"]
