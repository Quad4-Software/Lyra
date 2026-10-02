# Lyra browser build image. Multi-stage, rootless builder.
#
#   podman build --output type=local,dest=out .
#
# Writes lyra-<version>-linux-x86_64.tar.xz into ./out. Use
# --target build to keep the full toolchain image instead:
#
#   podman build --target build -t lyra-build .
#   podman run --rm -it lyra-build bash

FROM docker.io/library/ubuntu:24.04 AS base

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev \
    build-essential ccache curl git pkg-config \
    libasound2-dev libdbus-glib-1-dev libgtk-3-dev libpulse-dev \
    libx11-xcb-dev libxt-dev libxrandr-dev libxcomposite-dev \
    libxdamage-dev libxfixes-dev libdrm-dev libpango1.0-dev \
    libatk1.0-dev libcairo2-dev libgdk-pixbuf-2.0-dev \
    m4 unzip zip nasm xz-utils \
    clang llvm lld \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash builder
USER builder
WORKDIR /home/builder/lyra
ENV HOME=/home/builder \
    MOZBUILD_STATE_PATH=/home/builder/.mozbuild \
    PATH=/home/builder/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

FROM base AS source
COPY --chown=builder:builder . .
RUN ./scripts/fetch-firefox.sh firefox-src \
 && ./scripts/apply-overlay.sh firefox-src \
 && ./extensions/ublock/fetch.sh

FROM source AS toolchain
RUN cat mozconfig mozconfig.linux > firefox-src/mozconfig \
 && cd firefox-src \
 && MOZCONFIG=/home/builder/lyra/firefox-src/mozconfig \
    ./mach --no-interactive bootstrap --application-choice browser --no-system-changes

FROM toolchain AS build
ARG JOBS=2
ENV JOBS=${JOBS}
RUN ./scripts/container-build.sh

FROM scratch AS artifact
COPY --from=build /home/builder/lyra/out/ /
