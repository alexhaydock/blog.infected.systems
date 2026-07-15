#!/usr/bin/env bash
set -euxo pipefail

podman build -f Containerfile-dev -t hugo-dev .
podman run --rm -it -p "127.0.0.1:1313:1313" -v "$(pwd)/site:/opt:Z" localhost/hugo-dev serve --bind 0.0.0.0
