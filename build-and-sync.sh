#!/usr/bin/env bash
set -euo pipefail

# Recursively update Git submodules
git submodule update --init --recursive

# Optimise images
find ./content/ -iname '*.png' -exec optipng {} \;

# Build site
hugo

# Sync site to Wii
rsync -avsh --delete public/ root@[2a11:f2c0:ffcc::4]:/srv/www/htdocs/
