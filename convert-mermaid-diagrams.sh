#!/usr/bin/env bash
set -euo pipefail

# Check deps
if ! command -v mmdc >/dev/null 2>&1; then echo "Missing mmdc package" && echo "Install with:" && echo "  sudo npm install -g @mermaid-js/mermaid-cli" && exit 1; fi
if ! command -v chromium-browser >/dev/null 2>&1; then echo "Missing Chromium for Mermaid conversion" && echo "Install with:" && echo "  sudo dnf install chromium" && exit 1; fi

# Convert Mermaid diagrams in-place with mmdc for dark and light modes
find ./content/ -iname '*.mmd' -exec sh -c '
  for f do
    base="${f%.mmd}"
    
    # Dark mode
    mmdc -p ./puppeteer-config.json -t dark -b transparent -i "$f" -o "${base}_dark.svg"
    
    # Light mode
    mmdc -p ./puppeteer-config.json -t default -b transparent -i "$f" -o "${base}_light.svg"
  done
' sh {} +
