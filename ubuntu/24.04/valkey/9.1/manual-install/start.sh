#!/bin/bash

#
# Valkey 9.1 源码安装 — 启动
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

VALKEY_SERVER=/usr/local/valkey/bin/valkey-server
CONFFILE=/wwwdata/valkey/run/valkey.conf
ACLFILE=/wwwdata/misc/users.acl

if [ ! -x "$VALKEY_SERVER" ]; then
    echo "missing ${VALKEY_SERVER}" >&2
    exit 1
fi

if [ ! -f "$CONFFILE" ]; then
    echo "missing ${CONFFILE}" >&2
    exit 1
fi

if [ ! -f "$ACLFILE" ]; then
    echo "missing ${ACLFILE}" >&2
    exit 1
fi

"$VALKEY_SERVER" "$CONFFILE"
