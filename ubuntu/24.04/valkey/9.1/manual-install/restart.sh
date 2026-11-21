#!/bin/bash

#
# Valkey 9.1 源码安装 — 重启
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

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

bash "$SCRIPT_DIR/stop.sh"
bash "$SCRIPT_DIR/start.sh"
