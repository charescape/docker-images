#!/bin/bash

#
# Valkey 9.1 源码安装
#
# 运行环境：
#   CPU(s): 2 vCPU
#   Mem: 4 GiB
#   Disk: 100 GiB SSD
#   OS: Ubuntu 24.04
#   arch: x86_64
#   timezone: Asia/Shanghai
#   Docker Version: 未安装
#   Valkey Version: 9.1.4，源码编译
#   类型：独立单实例，非 cluster / sentinel
#

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

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

mkdir -p /wwwdata/valkey/data /wwwdata/valkey/run /wwwdata/misc

echo "Valkey 9.1.4 installation completed."
