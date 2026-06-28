#!/usr/bin/env sh
set -euxo pipefail

build() {
    podman build -t wiibuild .
    podman rm wiibuild
    podman create --name wiibuild localhost/wiibuild
    podman cp wiibuild:/nintendo.img.gz .
}

time build
