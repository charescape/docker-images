#!/bin/sh

set -eux

# One-shot boot prepare. The daemon is started by runit: /etc/service/mariadb/run
# Bind-mount of /wwwdata/misc is not seeded from the image.
mkdir -p /wwwdata/misc
if [ ! -f /wwwdata/misc/mariadb12v3.conf ]; then
  cp /etc/mariadb12v3.conf.default /wwwdata/misc/mariadb12v3.conf
fi

chown -R www-data:www-data /usr/local/mysql/
chown -R www-data:www-data /wwwdata/
