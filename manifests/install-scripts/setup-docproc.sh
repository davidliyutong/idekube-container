#!/bin/bash
set -e

# --break-system-packages allows installing into the system Python on
# PEP 668 distros (Ubuntu 24.04+). --ignore-installed prevents pip from
# trying to uninstall debian-managed packages (e.g. blinker), which
# fails with "RECORD file not found" because dpkg doesn't write one.
# Harmless on conda-managed images where conda's pip doesn't enforce
# the marker and there are no dpkg-installed Python packages.
PIP_FLAGS="--break-system-packages --ignore-installed"

DATA_PACKAGES="pandas numpy matplotlib scipy scikit-learn scikit-image networkx"
DOC_PACKAGES="pdfplumber pdfminer.six pypdf pypdfium2 pikepdf camelot-py python-docx python-pptx openpyxl reportlab img2pdf"
UTIL_PACKAGES="Pillow opencv-python beautifulsoup4 requests flask tqdm ipywidgets markitdown magika"
BROWSER_PACKAGES="playwright"

pip install $PIP_FLAGS --no-cache-dir $DATA_PACKAGES $DOC_PACKAGES $UTIL_PACKAGES $BROWSER_PACKAGES

# Install Playwright Chromium browser
playwright install --with-deps chromium
