#!/bin/bash

#
# Valkey 9.1 源码安装 — 停止
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

PIDFILE=/wwwdata/valkey/run/valkey.pid
STOP_TIMEOUT=60

if [ ! -f "$PIDFILE" ]; then
    exit 0
fi

PID=$(tr -d '[:space:]' < "$PIDFILE")

if ! [[ "$PID" =~ ^[0-9]+$ ]]; then
    echo "invalid pid in ${PIDFILE}" >&2
    exit 1
fi

if [ ! -d "/proc/${PID}" ]; then
    exit 0
fi

if ! kill -TERM "$PID" 2>/dev/null; then
    if [ ! -d "/proc/${PID}" ]; then
        exit 0
    fi
    echo "failed to signal pid ${PID}" >&2
    exit 1
fi

elapsed=0
while [ -d "/proc/${PID}" ]; do
    if [ "$elapsed" -ge "$STOP_TIMEOUT" ]; then
        echo "Valkey did not stop within ${STOP_TIMEOUT}s" >&2
        exit 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done
