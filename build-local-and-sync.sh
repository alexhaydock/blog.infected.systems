#!/usr/bin/env bash
set -euxo pipefail

podman build -f Containerfile-build-local -t hugo-build-local .
podman rm blog-local || true
podman create --name blog-local localhost/hugo-build-local
test -d site/public_local && rm -r site/public_local/
mkdir -p site/public_local/
podman cp blog-local:/opt/site/public/. site/public_local/
rsync -avsh -e 'ssh -i ~/.ssh/id_ed25519_Primary' --delete site/public_local/ root@[2a11:f2c0:ffcc::107]:/var/www/lighttpd/
