#!/bin/bash
set -e

ARCH=$(dpkg --print-architecture)
# Frist install the necessary dependencies
pip install -U pip

# If the Ascend is present
if [ -d "/usr/local/Ascend" ]; then
    if [ "$ARCH" = "arm64" ]; then
        pip install --no-cache-dir \
            attrs>=25.4.0 \
            decorator>=5.2.1 \
            numpy>=2.4.0 \
            psutil>=7.2.1 \
            pyyaml>=6.0.3 \
            scipy>=1.16.3 \
            torch==2.6.0 \
            torch-npu==2.6.0 \
            torchvision \
            tornado \
            absl-py \
            ml-dtypes \
            cloudpickle \
            tqdm

        # Install vLLM with Ascend support
        # pip install vllm==0.13.0
        # pip install vllm-ascend==0.13.0rc1
    else
        echo "Ascend AI environment setup is only supported on arm64 architecture."
        pip install torch==2.6.0 torchvision torchaudio
        pip install --no-cache-dir scipy tqdm
    fi
else
    # Otherwise, install the standard PyTorch environment
    pip install torch==2.6.0 torchvision torchaudio
    pip install --no-cache-dir scipy tqdm
fi
