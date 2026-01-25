# These arguments are passed in via the docker build command
ARG REGISTRY=docker.io \
    AUTHOR=davidliyutong \
    NAME=idekube-container \
    GIT_TAG=unknown \
    TAG_POSTFIX=

FROM ${REGISTRY}/${AUTHOR}/${NAME}:jupyter-base-${GIT_TAG}${TAG_POSTFIX} AS system

# Install packages
RUN apt-get update && apt-get install --fix-missing -y \
    tmate r-base \
    && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Configure Python Mirror to force using Tsinghua University mirror
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

# Configure Python environment
SHELL ["conda", "run", "-n", "base", "/bin/bash", "-c"]
RUN pip install -U pip && \
    pip install --no-cache-dir sympy numpy matplotlib scipy scikit-learn networkx pandas pydot graphviz jupyter six && \
    pip install --no-cache-dir symbtools ipydex ipython && \
    pip install --no-cache-dir --no-build-isolation pycartan

# Configure Python environment
RUN conda create -n pytorch python=3.11 -y
SHELL ["conda", "run", "-n", "pytorch", "/bin/bash", "-c"]
COPY manifests/install-scripts/setup-ascendai-env.sh /tmp/setup-ascendai-env.sh
RUN bash /tmp/setup-ascendai-env.sh && rm /tmp/setup-ascendai-env.sh && \
    pip install ipykernel && \
    python -m ipykernel install --name pytorch --display-name "Python (pytorch)" && \
    rm -rf /opt/miniconda3/envs/pytorch/share/jupyter/kernels/
SHELL ["/bin/bash", "-c"]