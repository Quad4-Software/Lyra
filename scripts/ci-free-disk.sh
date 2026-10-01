#!/usr/bin/env bash
# Free GitHub-hosted runner disk before a Firefox compile.

set -euo pipefail

df -h

sudo rm -rf \
  /usr/share/dotnet \
  /usr/local/lib/android \
  /opt/ghc \
  /opt/hostedtoolcache/CodeQL \
  /usr/share/swift \
  /usr/local/share/powershell \
  /usr/local/share/chromium \
  /usr/local/lib/node_modules \
  /opt/az \
  /usr/share/miniconda \
  /usr/local/.ghcup \
  /opt/microsoft \
  /usr/lib/jvm \
  /usr/lib/google-cloud-sdk \
  /opt/hostedtoolcache/go \
  /opt/hostedtoolcache/Python || true

sudo apt-get clean || true
sudo docker system prune -af || true

# Runners ship a small 3 GB swap already. Add 24 GB regardless: the build
# peaks past 16 GB of RAM under -j2. fallocate files can be rejected by
# swapon on some kernels, so write the file fully with dd.
if [[ ! -f /swapfile ]]; then
  sudo dd if=/dev/zero of=/swapfile bs=1M count=24576 status=none
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
fi
sudo swapon /swapfile
swapon --show

df -h
free -h
