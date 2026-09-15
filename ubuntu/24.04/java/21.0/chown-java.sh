#!/bin/sh

set -eux

# One-shot boot prepare. The daemon is started by runit: /etc/service/java/run
mkdir -p /wwwdata/java/m2
mkdir -p /wwwdata/java/logs
mkdir -p /wwwdata/java/tmp
mkdir -p /wwwdata/misc

# Do not chown /my_shared_dir (git and other sites live there).
chown -R www-data:www-data /wwwdata/
