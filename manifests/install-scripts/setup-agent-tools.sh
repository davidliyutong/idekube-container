#!/bin/bash
set -e

# Build toolchain, document conversion stack, headless Java, and a
# trimmed TeX Live for PDF compilation. The full texlive package is
# several GB and intentionally avoided — latex-recommended +
# fonts-recommended + xetex covers unicode/CJK via xelatex.

apt-get update
apt-get install --fix-missing -y \
    build-essential gcc g++ clang gdb \
    cmake ninja-build meson autoconf \
    graphviz \
    imagemagick ffmpeg tesseract-ocr \
    libreoffice \
    xvfb \
    openjdk-21-jre-headless \
    texlive-latex-recommended texlive-fonts-recommended texlive-xetex lmodern
apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*
