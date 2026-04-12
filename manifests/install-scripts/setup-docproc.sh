#!/bin/bash
set -e

# --break-system-packages allows installing into the system Python on
# PEP 668 distros (Ubuntu 24.04+). --ignore-installed prevents pip from
# trying to uninstall debian-managed packages (e.g. blinker), which
# fails with "RECORD file not found" because dpkg doesn't write one.
# Harmless on conda-managed images where conda's pip doesn't enforce
# the marker and there are no dpkg-installed Python packages.
PIP_FLAGS="--break-system-packages --ignore-installed"

DATA_PACKAGES="pandas==3.0.2 numpy==2.4.4 matplotlib==3.10.8 scipy==1.17.1 scikit-learn==1.8.0 scikit-image==0.26.0 networkx==3.6.1"
DOC_PACKAGES="pdfplumber==0.11.9 pdfminer.six==20251230 pypdf==5.9.0 pypdfium2==5.7.0 pikepdf==10.5.1 camelot-py==1.0.9 python-docx==1.2.0 python-pptx==1.0.2 openpyxl==3.1.5 reportlab==4.4.10 img2pdf==0.6.3"
UTIL_PACKAGES="Pillow==12.2.0 opencv-python==4.13.0.92 beautifulsoup4==4.14.3 requests==2.33.1 flask==3.1.3 tqdm==4.67.3 ipywidgets==8.1.8 markitdown==0.1.5 magika==0.6.3"
BROWSER_PACKAGES="playwright==1.58.0"

pip install $PIP_FLAGS --no-cache-dir $DATA_PACKAGES $DOC_PACKAGES $UTIL_PACKAGES $BROWSER_PACKAGES

# Install Playwright Chromium browser into PLAYWRIGHT_BROWSERS_PATH
# (a system-wide path so the unprivileged idekube user can launch it
# even when /home/idekube is volume-mounted at runtime).
playwright install --with-deps chromium
[ -n "$PLAYWRIGHT_BROWSERS_PATH" ] && chmod -R go+rX "$PLAYWRIGHT_BROWSERS_PATH"
