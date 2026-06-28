#!/usr/bin/env bash
set -euxo pipefail

build() {
    podman build -t wiibuild .
    podman rm wiibuild || true
    podman create --name wiibuild localhost/wiibuild
    podman cp wiibuild:/nintendo.img.gz .
}

time build
