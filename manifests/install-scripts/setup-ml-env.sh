#!/bin/bash
set -e

ARCH=$(dpkg --print-architecture)
# Frist install the necessary dependencies
pip install -U pip

BASE_PACKAGES="sympy==1.14.0 numpy==2.4.3 matplotlib==3.10.8 scipy==1.17.1 scikit-learn==1.8.0 networkx==3.6.1 pandas==3.0.1 pydot==4.0.1 graphviz==0.21 jupyter==1.1.1 six==1.17.0 ipywidgets==8.1.8 tqdm==4.67.3"
TORCH_PACKAGES="torch==2.9.0 torchvision==0.24.0 torchaudio==2.9.0 transformers==5.3.0 accelerate==1.13.0"
TORCH_NPU_PACKAGES="torch-npu==2.9.0"
ML_UTILS_PACKAGES="attrs==25.4.0 decorator==5.2.1 psutil==7.2.2 pyyaml==6.0.3 tornado==6.5.5 absl-py==2.4.0 ml-dtypes==0.5.4 cloudpickle==3.1.2 protobuf==7.34.0 evaluate==0.4.6"

# If the Ascend is present
if [ -d "/usr/local/Ascend" ]; then
    if [ "$ARCH" = "arm64" ]; then
        pip install --no-cache-dir ${BASE_PACKAGES} ${TORCH_PACKAGES} ${TORCH_NPU_PACKAGES} ${ML_UTILS_PACKAGES}
    else
        echo "Ascend AI environment setup is only supported on arm64 architecture."
        pip install --no-cache-dir ${BASE_PACKAGES} ${TORCH_PACKAGES} ${ML_UTILS_PACKAGES}
    fi
else
    # Otherwise, install the standard PyTorch environment
    pip install  --no-cache-dir ${BASE_PACKAGES} ${TORCH_PACKAGES} ${ML_UTILS_PACKAGES}
fi
