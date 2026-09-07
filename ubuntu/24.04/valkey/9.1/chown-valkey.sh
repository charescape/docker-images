#!/bin/sh

set -eux

# One-shot boot prepare. The daemon is started by runit: /etc/service/valkey/run
mkdir -p /wwwdata/valkey/data
mkdir -p /wwwdata/valkey/run
mkdir -p /wwwdata/misc

# Existing run volumes are not re-seeded from the image.
# Bind-mount of /wwwdata/misc is not seeded from the image; users.acl must already be there.
if [ ! -f /wwwdata/valkey/run/valkey.conf ]; then
  cp /usr/local/valkey/valkey.conf.default /wwwdata/valkey/run/valkey.conf
fi

chown -R www-data:www-data /usr/local/valkey/
chown -R www-data:www-data /wwwdata/
