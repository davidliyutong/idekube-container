#!/bin/bash
set -e

apt-get update
apt-get install -y --no-install-recommends \
    libxau6 libxdmcp6 libxcb1 libxext6 libx11-6 \
    libglvnd0 libgl1 libglx0 libegl1 libgles2 \
    libglvnd-dev libgl1-mesa-dev libegl1-mesa-dev libgles2-mesa-dev vulkan-tools
apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# OpenGL
mkdir -p /usr/share/glvnd/egl_vendor.d/
cat <<EOF > /usr/share/glvnd/egl_vendor.d/10_nvidia.json
{
    "file_format_version" : "1.0.0",
    "ICD": {
        "library_path": "libEGL_nvidia.so.0"
    }
}
EOF

# Vulkan API
VULKAN_API_VERSION=$(dpkg -s libvulkan1 | grep -oP 'Version: [0-9|\.]+' | grep -oP '[0-9]+(\.[0-9]+)(\.[0-9]+)')

# Vulkan
mkdir -p /etc/vulkan/icd.d/
cat <<EOF > /etc/vulkan/icd.d/nvidia_icd.json
{
    "file_format_version" : "1.0.0",
    "ICD": {
        "library_path": "libGLX_nvidia.so.0",
        "api_version" : "${VULKAN_API_VERSION}"
    }
}
EOF