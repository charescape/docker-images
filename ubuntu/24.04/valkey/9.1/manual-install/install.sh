#!/bin/bash

set -e

apt update
apt -y install \
    build-essential \
    pkg-config \
    libssl-dev \
    ca-certificates \
    curl

cd /usr/local/src

curl -fL \
    -o valkey-9.1.4.tar.gz \
    https://github.com/valkey-io/valkey/archive/refs/tags/9.1.4.tar.gz

tar -xzf valkey-9.1.4.tar.gz
cd valkey-9.1.4

make -j"$(nproc)" \
    BUILD_TLS=yes \
    USE_SYSTEMD=no \
    USE_REDIS_SYMLINKS=no \
    PREFIX=/usr/local/valkey

sudo make install \
    BUILD_TLS=yes \
    USE_SYSTEMD=no \
    USE_REDIS_SYMLINKS=no \
    PREFIX=/usr/local/valkey

# Verify installation
/usr/local/valkey/bin/valkey-server --version
/usr/local/valkey/bin/valkey-cli --version

echo "Valkey 9.1.4 installation completed."
