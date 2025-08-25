#!/usr/bin/env bash
set -euo pipefail

# Recursively update Git submodules
git submodule update --init --recursive

# Optimise images
find ./content/ -iname '*.png' -exec optipng {} \;

# Build site
hugo

# Sync site to Wii
rsync -avsh --delete public/ root@192.168.191.88:/srv/www/htdocs/
