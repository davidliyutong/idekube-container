# These arguments are passed in via the docker build command
ARG REGISTRY=docker.io \
    AUTHOR=davidliyutong \
    NAME=idekube-container \
    GIT_TAG=unknown

FROM ${REGISTRY}/${AUTHOR}/${NAME}:jupyter-base-${GIT_TAG} AS system

ARG PIP_MIRROR_URL="https://mirror.sjtu.edu.cn/pypi/web/simple" \
    USE_PIP_MIRROR="true"

# Install packages
RUN apt-get update && apt-get install --fix-missing -y \
    tmate r-base \
    && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Install the R kernel
RUN R -e "install.packages(c('IRkernel', 'repr', 'IRdisplay', 'evaluate', 'crayon', 'pbdZMQ', 'devtools', 'uuid', 'digest'), repos='https://cloud.r-project.org/')" && \
    R -e "IRkernel::installspec(user = FALSE)"

# Configure Python Mirror
RUN if [ ${USE_PIP_MIRROR} != "false" ]; then \
        pip config set global.index-url ${PIP_MIRROR_URL}; \
    fi;

# Configure Python environment
RUN . /opt/miniconda3/etc/profile.d/conda.sh && conda activate && \
    pip install -U pip && \
    pip install --no-cache-dir sympy numpy matplotlib scipy scikit-learn networkx pandas pydot graphviz jupyter && \
    pip install --no-cache-dir symbtools ipydex ipython && \
    pip install --no-cache-dir pycartan

## Install iverilog
COPY manifests/install-scripts/setup-iverilog.sh /tmp/setup-iverilog.sh
RUN /bin/bash /tmp/setup-iverilog.sh

## Install Digital
COPY manifests/install-scripts/setup-digital.sh /tmp/setup-digital.sh
RUN /bin/bash /tmp/setup-digital.sh
