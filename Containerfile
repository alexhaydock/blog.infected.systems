FROM ghcr.io/mermaid-js/mermaid-cli/mermaid-cli as buildsite

# Return to rootful user so we can install packages
# and avoid permission errors when mounting our
# local working directory
USER root

# Install Hugo & other deps
RUN apk --no-cache add \
      hugo \
      optipng

# Copy blog content into build container
COPY site/ /opt/blog
WORKDIR /opt/blog

RUN <<EOF
# Optimise images
find ./content/ -iname '*.png' -exec optipng {} \;

# Convert Mermaid diagrams in-place with mmdc for dark and light modes
find ./content/ -iname '*.mmd' -exec sh -c '
  for f do
    base="${f%.mmd}"
    # Dark mode
    /home/mermaidcli/node_modules/.bin/mmdc -p /puppeteer-config.json -t dark -b transparent -i "$f" -o "${base}_dark.svg"
    # Light mode
    /home/mermaidcli/node_modules/.bin/mmdc -p /puppeteer-config.json -t default -b transparent -i "$f" -o "${base}_light.svg"
  done
' sh {} +

# Remove output dir if present
if [ -d /opt/blog/public/ ]; then
  rm -rv "/opt/blog/public/"
fi

# Build site with hugo
mkdir -p /opt/blog/public
hugo
EOF

# Use Ubuntu 24.04 so local builds are the same as GitHub Actions builds
FROM docker.io/library/ubuntu:24.04 as buildbase

# Install deps
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      curl \
      git \
      zlib1g-dev

FROM buildbase as buildpkgsrc
# Build step
# - Mount /opt as tmpfs
# - Clone the pkgsrc sources into it
# - Build pkgsrc into /usr/pkg
RUN --mount=type=tmpfs,target=/opt <<EOF
git clone --depth 1 https://github.com/NetBSD/pkgsrc.git /opt/pkgsrc
(cd /opt/pkgsrc/bootstrap && ./bootstrap --prefix /usr/pkg --unprivileged)
EOF

FROM buildbase as buildimg

# Bring in pkgsrc from pkgsrc build container
COPY --from=buildpkgsrc /usr/pkg /usr/pkg

# Bring in built site from site build container
COPY --from=buildsite /opt/blog/public /site

# Inject our own configs
COPY evbppc_wii_icon.png /files/evbppc_wii_icon.png
COPY evbppc_wii_meta.xml /files/evbppc_wii_meta.xml
COPY nintendo.conf /files/nintendo.conf

# Build step
# - Clone the NetBSD sources into /opt
# - Copy our overlay files into the tree
# - Run the build script
# - Copy the image out of tmpfs and to the root of the container
#
# I don't use tmpfs for /opt anymore for this step since GitHub Actions
# runners will run out of RAM and throw a "No space left on device"
# error if we do
RUN <<EOF
git clone --depth 1 https://github.com/NetBSD/src.git /opt/netbsd
cp -fv /files/evbppc_wii_icon.png /opt/netbsd/distrib/utils/embedded/files/evbppc_wii_icon.png
cp -fv /files/evbppc_wii_meta.xml /opt/netbsd/distrib/utils/embedded/files/evbppc_wii_meta.xml
cp -fv /files/nintendo.conf /opt/netbsd/distrib/utils/embedded/conf/nintendo.conf
(cd /opt/netbsd && ./build.sh -j$(nproc) -m evbppc -a powerpc release)
cp -fv /opt/netbsd/obj/releasedir/evbppc/binary/gzimg/nintendo.img.gz /nintendo.img.gz
EOF

# Dump just the built image out into a fresh scratch container
FROM scratch
COPY --from=buildimg /nintendo.img.gz /nintendo.img.gz
