#!/bin/sh

set -eux

# One-shot boot prepare. The daemon is started by runit: /etc/service/php-fpm/run
chown -R www-data:www-data /usr/local/php/
chown -R www-data:www-data /wwwdata/

if [ -d /my_shared_dir ]; then
  chown -R www-data:www-data /my_shared_dir
fi
