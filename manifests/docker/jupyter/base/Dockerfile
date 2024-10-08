FROM ubuntu:20.04 AS system

# These arguments are passed in via the docker build command
ARG TZ=Asia/Shanghai \
    WEBSOCAT_VERSION=1.13.0 \
    APT_MIRROR="mirror.sjtu.edu.cn" \
    USE_APT_MIRROR="false" \
    TINI_VERSION=0.19.0

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
RUN apt-get update && apt-get install apt-utils -y \
    && apt-get install -y --no-install-recommends --allow-unauthenticated wget curl vim jq git htop \
    supervisor sudo net-tools xz-utils nginx \
    python3 python3-pip python3-setuptools python3-wheel python3-dev build-essential cmake \
    # OpenSSH
    && apt-get install -y openssh-server \
    && apt-get autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# tini to fix subreap
RUN wget https://github.com/krallin/tini/archive/v${TINI_VERSION}.tar.gz -O v${TINI_VERSION}.tar.gz  \
    && tar zxf v${TINI_VERSION}.tar.gz \
    && export CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"; \
    cd tini-${TINI_VERSION}; cmake . && make && make install \
    && cd ..; rm -r tini-${TINI_VERSION} v${TINI_VERSION}.tar.gz

# Setup the websocat and ssh
RUN arch=$(uname -m); \
    if [ "$arch" = "arm64" ]; then arch="aarch64"; fi; \
    wget https://github.com/vi/websocat/releases/download/v${WEBSOCAT_VERSION}/websocat.$arch-unknown-linux-musl -O /usr/local/bin/websocat \
    && chmod +x /usr/local/bin/websocat
RUN mkdir -p /run/sshd && echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Install Miniconda
RUN arch=$(uname -m); \
    if [ "$arch" = "arm64" ]; then arch="aarch64"; fi; \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-$arch.sh -O /tmp/miniconda.sh \
    && /bin/bash /tmp/miniconda.sh -b -p /opt/miniconda3 \
    && rm /tmp/miniconda.sh
ENV PATH=/opt/miniconda3/bin:$PATH

# Install Jupyter
RUN python3 -m pip install --no-cache-dir jupyterlab
# Configure nginx server for container
RUN sed -i 's|worker_processes .*|worker_processes 1;|' /etc/nginx/nginx.conf

# Create the IDEKube user with home and bash shell, set the password to 'idekube'
# Allow 'idekube' to run sudo commands without password by modifying the sudoers file
RUN useradd -m -s /bin/bash idekube \
    && echo "idekube:idekube" | chpasswd \
    && echo "idekube ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo

# Setup the root filesystem
COPY artifacts/jupyter/rootfs /

# Setting Environment Variables for startup.sh
ENV SHELL=/bin/bash \
    USERNAME=idekube \
    USERID=1000

EXPOSE 80
ENTRYPOINT ["/startup.sh"]