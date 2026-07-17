#!/usr/bin/env bash
set -euxo pipefail

podman build -f Containerfile-build-emf -t hugo-build-emf .
podman rm blog-emf || true
podman create --name blog-emf localhost/hugo-build-emf
test -d site/public_emf && rm -r site/public_emf/
mkdir -p site/public_emf/
podman cp blog-emf:/opt/site/public/. site/public_emf/
# No rsync on the NetBSD image
ssh -i ~/.ssh/id_ed25519_Primary root@2a09:a447:2026:e621:e3b7:1189:cef9:8ec7 rm -rfv /srv/www/htdocs/
scp -i ~/.ssh/id_ed25519_Primary -r site/public_emf/ root@[2a09:a447:2026:e621:e3b7:1189:cef9:8ec7]:/srv/www/htdocs/
