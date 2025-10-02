#!/usr/bin/env bash
set -euo pipefail

# Check deps
if ! command -v optipng >/dev/null 2>&1; then echo "Missing optipng package" && exit 1; fi
if ! command -v hugo >/dev/null 2>&1; then echo "Missing hugo package" && exit 1; fi

# Recursively update Git submodules
git submodule update --init --recursive

# Optimise images
find ./content/ -iname '*.png' -exec optipng {} \;

# Build site
hugo

# Sync site to Wii
rsync -e 'ssh -p 38000' -avsh --delete public/ root@[2a11:f2c0:ffcc::4]:/srv/www/htdocs/
