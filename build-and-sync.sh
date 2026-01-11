#!/usr/bin/env bash
set -euo pipefail

# Check deps
if ! command -v optipng >/dev/null 2>&1; then echo "Missing optipng package" && exit 1; fi
if ! command -v hugo >/dev/null 2>&1; then echo "Missing hugo package" && exit 1; fi
if ! command -v mmdc >/dev/null 2>&1; then echo "Missing mmdc package (from mermaid-cli)" && exit 1; fi
if ! command -v chromium-browser >/dev/null 2>&1; then echo "Missing Chromium for Mermaid conversion" && exit 1; fi

# Optimise images
find ./content/ -iname '*.png' -exec optipng {} \;

# Convert Mermaid diagrams in-place with mmdc for dark and light modes
export CHROME_PATH=$(which chromium)
find ./content/ -iname '*.mmd' -exec sh -c '
  for f do
    base="${f%.mmd}"
    # Dark mode
    mmdc -t dark -b transparent -i "$f" -o "${base}_dark.svg"
    # Light mode
    mmdc -t default -b transparent -i "$f" -o "${base}_light.svg"
  done
' sh {} +

# Remove existing output dir
rm -rv "${PWD}/public/"

# Build site
hugo

# Sync site to Wii
rsync -e 'ssh -p 38000' -avsh --delete public/ root@[2a11:f2c0:ffcc::4]:/srv/www/htdocs/
