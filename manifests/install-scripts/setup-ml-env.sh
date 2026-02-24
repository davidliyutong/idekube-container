#!/bin/bash
set -e

ARCH=$(dpkg --print-architecture)
# Frist install the necessary dependencies
pip install -U pip

BASE_PACKAGES="sympy numpy>=2.4.0 matplotlib scipy>=1.16.3 scikit-learn networkx pandas pydot graphviz jupyter six ipywidgets tqdm"
TORCH_PACKAGES="torch==2.9.0 torchvision torchaudio transformers accelerate"
TORCH_NPU_PACKAGES="torch-npu==2.9.0"
ML_UTILS_PACKAGES="attrs>=25.4.0 decorator>=5.2.1 psutil>=7.2.1 pyyaml>=6.0.3 tornado absl-py ml-dtypes cloudpickle protobuf evaluate"

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
