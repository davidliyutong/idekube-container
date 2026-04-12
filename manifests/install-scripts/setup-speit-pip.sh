#!/bin/bash
set -e

# Pinned Python packages for SPEIT teaching environments.
# Installed into the currently active conda environment (typically base).

BASE_PACKAGES="sympy==1.14.0 numpy==2.4.2 matplotlib==3.10.8 scipy==1.17.1 scikit-learn==1.8.0 networkx==3.6.1 pandas==3.0.1 pydot==4.0.1 graphviz==0.21 jupyter==1.1.1 six==1.17.0"
CONTROL_PACKAGES="symbtools==0.4.1 ipydex==0.20.0 ipython==9.10.0"

pip install -U pip
pip install --no-cache-dir $BASE_PACKAGES
pip install --no-cache-dir $CONTROL_PACKAGES
pip install --no-cache-dir --no-build-isolation pycartan==0.1.5
