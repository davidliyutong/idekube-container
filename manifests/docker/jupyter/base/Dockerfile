FROM ubuntu:24.04 AS system

# These arguments are passed in via the docker build command
ARG TZ=Asia/Shanghai \
    WEBSOCAT_VERSION=1.13.0 \
    APT_MIRROR="mirror.sjtu.edu.cn" \
    USE_APT_MIRROR="false" \
    TINI_VERSION=0.19.0

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

# Install Miniconda
RUN bash /tmp/install-scripts/setup-miniconda.sh
ENV PATH=/opt/miniconda3/bin:$PATH

# Install Jupyter
RUN python3 -m pip install --no-cache-dir jupyterlab

# Install useful JupyterLab plugins
RUN python3 -m pip install --no-cache-dir \
    jupyterlab-git jupyterlab-lsp jupyterlab-kite jupyterlab-drawio 

# Create the IDEKube user with home and bash shell
RUN bash /tmp/install-scripts/setup-user.sh
ENV SHELL=/bin/bash \
    USERNAME=idekube \
    USERID=1000

# Setup the root filesystem
COPY artifacts/jupyter/rootfs /
COPY artifacts/startup-scripts /

EXPOSE 80
ENTRYPOINT ["/startup.sh"]