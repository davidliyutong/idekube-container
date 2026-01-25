# These arguments are passed in via the docker build command
ARG REGISTRY=docker.io \
    AUTHOR=davidliyutong \
    NAME=idekube-container \
    GIT_TAG=unknown \
    TAG_POSTFIX=

FROM ${REGISTRY}/${AUTHOR}/${NAME}:jupyter-base-${GIT_TAG}${TAG_POSTFIX} AS system

ARG PIP_MIRROR_URL="https://mirror.sjtu.edu.cn/pypi/web/simple" \
    USE_PIP_MIRROR="true"

# Install packages
RUN apt-get update && apt-get install --fix-missing -y \
    tmate r-base \
    && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Configure Python Mirror
RUN if [ ${USE_PIP_MIRROR} != "false" ]; then \
        pip config set global.index-url ${PIP_MIRROR_URL}; \
    fi;

# Configure Python environment
SHELL ["conda", "run", "-n", "base", "/bin/bash", "-c"]
RUN pip install -U pip && \
    pip install --no-cache-dir sympy numpy matplotlib scipy scikit-learn networkx pandas pydot graphviz jupyter six && \
    pip install --no-cache-dir symbtools ipydex ipython && \
    pip install --no-cache-dir --no-build-isolation pycartan
SHELL ["/bin/bash", "-c"]