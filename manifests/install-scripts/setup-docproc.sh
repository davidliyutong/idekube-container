#!/bin/bash
set -e

pip install -U pip

DATA_PACKAGES="pandas numpy matplotlib scipy scikit-learn scikit-image networkx"
DOC_PACKAGES="pdfplumber pdfminer.six pypdf pypdfium2 pikepdf camelot-py python-docx python-pptx openpyxl reportlab img2pdf"
UTIL_PACKAGES="Pillow opencv-python beautifulsoup4 requests flask tqdm ipywidgets markitdown magika"
BROWSER_PACKAGES="playwright"

pip install --no-cache-dir $DATA_PACKAGES $DOC_PACKAGES $UTIL_PACKAGES $BROWSER_PACKAGES

# Install Playwright Chromium browser
playwright install --with-deps chromium
