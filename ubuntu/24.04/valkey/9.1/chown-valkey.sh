#!/bin/sh

set -eux

# One-shot boot prepare. The daemon is started by runit: /etc/service/valkey/run
mkdir -p /wwwdata/valkey/data
mkdir -p /wwwdata/valkey/run
mkdir -p /wwwdata/misc

# Existing run volumes are not re-seeded from the image.
if [ ! -f /wwwdata/valkey/run/valkey.conf ]; then
  cp /usr/local/valkey/valkey.conf.default /wwwdata/valkey/run/valkey.conf
fi
if [ ! -f /wwwdata/valkey/run/users.acl ]; then
  cp /usr/local/valkey/users.acl.default /wwwdata/valkey/run/users.acl
fi

chown -R www-data:www-data /usr/local/valkey/
chown -R www-data:www-data /wwwdata/
