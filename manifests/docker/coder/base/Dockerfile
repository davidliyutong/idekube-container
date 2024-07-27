FROM ubuntu:20.04 as system

# These arguments are passed in via the docker build command
ARG TZ=Asia/Shanghai

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
RUN apt-get update && apt-get upgrade -y && apt-get install apt-utils -y \
    && apt-get install -y --no-install-recommends software-properties-common curl apache2-utils \
    && apt-get update \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
    supervisor nginx sudo net-tools zenity xz-utils dbus-x11 x11-utils alsa-utils mesa-utils libgl1-mesa-dri wget \
    python3 python3-pip python3-setuptools python3-wheel python3-dev build-essential cmake

# install debs error if combine together
RUN apt-get update \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
    xvfb x11vnc \
    vim-tiny ttf-ubuntu-font-family ttf-wqy-zenhei

# Desktop
RUN apt-get update \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
    lxde gtk2-engines-murrine gnome-themes-standard gtk2-engines-pixbuf gtk2-engines-murrine arc-theme

# tini to fix subreap
ARG TINI_VERSION=0.19.0
RUN wget https://github.com/krallin/tini/archive/v${TINI_VERSION}.tar.gz -O v${TINI_VERSION}.tar.gz  \
    && tar zxf v${TINI_VERSION}.tar.gz \
    && export CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"; \
    cd tini-${TINI_VERSION}; cmake . && make && make install \
    && cd ..; rm -r tini-${TINI_VERSION} v${TINI_VERSION}.tar.gz

# Firefox
# COPY artifacts/rootfs/etc/apt/preferences.d/firefox-no-snap /etc/apt/preferences.d/firefox-no-snap
RUN apt-get update && apt-get install -y firefox libpci3

# # Killsession Utility
# COPY ./tools/utility/killsession/ /tmp/killsession/
# RUN cd /tmp/killsession && bash setup.bash && rm -rf /tmp/killsession

# noVNC
COPY third_party/noVNC /var/lib/novnc
COPY third_party/websockify /var/lib/novnc/utils/websockify

# Create the IDEKube user with home and bash shell, set the password to 'idekube'
# Allow 'idekube' to run sudo commands without password by modifying the sudoers file
RUN useradd -m -s /bin/bash idekube \
    && echo "idekube:idekube" | chpasswd \
    && echo "idekube ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo

# Setup the root filesystem
COPY artifacts/rootfs /

RUN apt-get autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# ENTRYPOINT [ "/startup.sh" ]
