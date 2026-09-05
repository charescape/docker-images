#!/bin/sh

set -eux

# One-shot boot prepare. The daemon is started by runit: /etc/service/openresty/run
mkdir -p /wwwdata/openresty/logs
mkdir -p /wwwdata/openresty/run
mkdir -p /wwwdata/openresty/nginxconf/ssl
mkdir -p /wwwdata/openresty/nginxconf/http.d
mkdir -p /wwwdata/openresty/nginxconf/rtmp.d

# Bind-mounting an empty nginxconf hides the image placeholders; seed so include *.conf still works.
set -- /wwwdata/openresty/nginxconf/http.d/*.conf
if [ ! -f "$1" ]; then
  printf '%s\n' '# Add extra http server blocks here.' > /wwwdata/openresty/nginxconf/http.d/00-placeholder.conf
fi
set -- /wwwdata/openresty/nginxconf/rtmp.d/*.conf
if [ ! -f "$1" ]; then
  printf '%s\n' '# Add rtmp / stream blocks here.' > /wwwdata/openresty/nginxconf/rtmp.d/00-placeholder.conf
fi

chown -R www-data:www-data /usr/local/openresty/
chown -R www-data:www-data /wwwdata/
