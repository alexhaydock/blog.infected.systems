#!/usr/bin/env bash
set -euo pipefail

# Build site in hugo build container
podman build -t hugobuilder .

# Instantiate a blank version of the container ready to copy our site out of it
podman rm hugobuilder || true
podman create --name hugobuilder localhost/hugobuilder

# Copy site out of the container
mkdir -p $(pwd)/public
podman cp hugobuilder:/site/. "$(pwd)/public/"

# Sync site to Wii
rsync -e 'ssh -p 38000' -avsh --delete public/ root@[2a11:f2c0:ffcc::4]:/srv/www/htdocs/
