FROM phusion/baseimage:noble-1.0.3

LABEL maintainer="charescape@outlook.com"

ENV TZ="Asia/Shanghai"
ENV OPENRESTY_VERSION="1.31.8.1"
ENV OPENRESTY_HASH="b569c63b420f80a4ac8466f2deffe73ed93ab760026532e039c3658409a997f4"
ENV VTS_VERSION="0.2.7"
ENV VTS_HASH="0003bfa57da2106367fdc3f87760910c046e7df5545db73c880fc2b80350b14c"
ENV FLV_VERSION="1.2.15"
ENV FLV_HASH="ac963f9802b9ec4cc00f1958526f17c1c17f26489604539138c7758985c797d4"
ENV PHP_VERSION="8.4.27"
ENV PHP_HASH="5bafed9994c1a49796b25b5f61c22c9183bfe046b6acc7b363842d03c77f972f"
ENV COMPOSER_VERSION="2.11.1"
ENV COMPOSER_HASH="6f1b891e1d4927d62740276c540fb490e47689e19e102c49e8da849794882f8c"
ENV KILL_PROCESS_TIMEOUT=60
ENV KILL_ALL_PROCESSES_TIMEOUT=60
ENV PATH="/usr/local/openresty/nginx/sbin:/usr/local/php/bin:/usr/local/php/sbin:/usr/local/markitdown/bin:${PATH}"

COPY ubuntu/24.04/openresty-php/8.4/chown-openresty.sh  /etc/my_init.d/
COPY ubuntu/24.04/openresty-php/8.4/chown-php.sh  /etc/my_init.d/
COPY ubuntu/24.04/openresty-php/8.4/nginx.conf  /usr/local/src/
COPY ubuntu/24.04/openresty-php/8.4/openresty.run  /usr/local/src/
COPY ubuntu/24.04/openresty-php/8.4/php.ini  /usr/local/src/
COPY ubuntu/24.04/openresty-php/8.4/php-fpm.conf  /usr/local/src/
COPY ubuntu/24.04/openresty-php/8.4/www.conf  /usr/local/src/
COPY ubuntu/24.04/openresty-php/8.4/php-fpm.run  /usr/local/src/
COPY ubuntu/24.04/openresty-php/8.4/nginxconf/http.d/00-placeholder.conf  /wwwdata/openresty/nginxconf/http.d/
COPY ubuntu/24.04/openresty-php/8.4/nginxconf/rtmp.d/00-placeholder.conf  /wwwdata/openresty/nginxconf/rtmp.d/

SHELL ["/bin/bash", "-c"]

RUN set -eux \
&& set -o pipefail \
&& export DEBIAN_FRONTEND=noninteractive \
\
&& free -m            \
\
&& apt -y update            \
&& apt -yq -o Dpkg::Options::="--force-confold" upgrade \
&& apt -y autoremove        \
\
\
&& mkdir -p /wwwdata/www \
&& mkdir -p /wwwdata/misc \
&& mkdir -p /wwwdata/openresty/logs \
&& mkdir -p /wwwdata/openresty/run \
&& mkdir -p /wwwdata/openresty/nginxconf/ssl \
&& mkdir -p /wwwdata/openresty/nginxconf/http.d \
&& mkdir -p /wwwdata/openresty/nginxconf/rtmp.d \
&& mkdir -p /wwwdata/php/run \
&& mkdir -p /wwwdata/php/log \
&& mkdir -p /wwwdata/php/sessions \
&& chown -R www-data:www-data /wwwdata \
\
&& apt -yq --no-install-recommends install tzdata \
sudo                            \
build-essential                 \
autoconf                        \
pkg-config                      \
ca-certificates                 \
wget                            \
curl                            \
git                             \
unzip                           \
p7zip-full                      \
perl                            \
re2c                            \
bison                           \
libtool                         \
libxml2-dev                     \
libssl-dev                      \
libcurl4-openssl-dev            \
libpcre2-dev                    \
zlib1g-dev                      \
libxslt1-dev                    \
libsqlite3-dev                  \
libbz2-dev                      \
libpng-dev                      \
libavif-dev                     \
libwebp-dev                     \
libjpeg-dev                     \
libxpm-dev                      \
libfreetype6-dev                \
libgmp-dev                      \
libonig-dev                     \
libreadline-dev                 \
libsodium-dev                   \
libargon2-dev                   \
libtidy-dev                     \
libzip-dev                      \
libzstd-dev                     \
libpq-dev                       \
libcapstone-dev                 \
libexpat1-dev                   \
\
\
&& chmod +x /etc/my_init.d/chown-openresty.sh \
&& chmod +x /etc/my_init.d/chown-php.sh \
\
&& apt -yq --no-install-recommends install zstd shellcheck shfmt jq curl util-linux \
\
&& cd /usr/local/src \
\
&& wget --no-verbose https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz \
&& echo "${OPENRESTY_HASH} *openresty-${OPENRESTY_VERSION}.tar.gz" | sha256sum --check \
\
&& wget --no-verbose -O nginx-module-vts-${VTS_VERSION}.tar.gz https://github.com/vozlt/nginx-module-vts/archive/refs/tags/v${VTS_VERSION}.tar.gz \
&& echo "${VTS_HASH} *nginx-module-vts-${VTS_VERSION}.tar.gz" | sha256sum --check \
\
&& wget --no-verbose -O nginx-http-flv-module-${FLV_VERSION}.tar.gz https://github.com/winshining/nginx-http-flv-module/archive/refs/tags/v${FLV_VERSION}.tar.gz \
&& echo "${FLV_HASH} *nginx-http-flv-module-${FLV_VERSION}.tar.gz" | sha256sum --check \
\
&& tar -zxf openresty-${OPENRESTY_VERSION}.tar.gz \
&& tar -zxf nginx-module-vts-${VTS_VERSION}.tar.gz \
&& tar -zxf nginx-http-flv-module-${FLV_VERSION}.tar.gz \
\
\
&& cd /usr/local/src/openresty-${OPENRESTY_VERSION} \
&& ./configure --prefix=/usr/local/openresty \
--with-threads \
--with-file-aio \
--with-http_ssl_module \
--with-http_v2_module \
--with-http_v3_module \
--with-http_realip_module \
--with-http_addition_module \
--with-http_sub_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_auth_request_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_slice_module \
--with-http_stub_status_module \
--without-mail_pop3_module \
--without-mail_imap_module \
--without-mail_smtp_module \
--with-stream \
--with-stream_ssl_module \
--with-stream_realip_module \
--with-stream_ssl_preread_module \
--with-pcre \
--with-pcre-jit \
--add-dynamic-module=/usr/local/src/nginx-module-vts-${VTS_VERSION} \
--add-dynamic-module=/usr/local/src/nginx-http-flv-module-${FLV_VERSION} \
\
&& make -j$(nproc --all) \
&& sleep 3s \
&& make install \
\
&& cd /usr/local/src \
&& rm -f /usr/local/openresty/nginx/conf/nginx.conf \
&& mv ./nginx.conf /usr/local/openresty/nginx/conf/nginx.conf \
\
&& chown -R www-data:www-data /usr/local/openresty \
&& chown -R www-data:www-data /wwwdata \
\
&& /usr/local/openresty/nginx/sbin/nginx -t \
&& /usr/local/openresty/nginx/sbin/nginx \
&& sleep 3s \
&& /usr/local/openresty/nginx/sbin/nginx -s stop \
\
&& mkdir -p /etc/service/openresty \
&& cp /usr/local/src/openresty.run /etc/service/openresty/run \
&& chmod +x /etc/service/openresty/run \
\
\
&& cd /usr/local \
&& wget --no-verbose https://curl.se/ca/cacert.pem \
&& wget --no-verbose https://curl.se/ca/cacert.pem.sha256 \
&& sha256sum --check cacert.pem.sha256 \
&& rm cacert.pem.sha256 \
\
&& cd /usr/local/src \
\
&& wget --no-verbose https://www.php.net/distributions/php-${PHP_VERSION}.tar.gz \
&& echo "${PHP_HASH} *php-${PHP_VERSION}.tar.gz" | sha256sum --check \
\
&& wget --no-verbose https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar \
&& echo "${COMPOSER_HASH} *composer.phar" | sha256sum --check \
\
&& tar -zxf php-${PHP_VERSION}.tar.gz \
\
\
&& cd /usr/local/src/php-${PHP_VERSION} \
&& ./configure --prefix=/usr/local/php \
--enable-option-checking=fatal \
--with-config-file-path=/usr/local/php/etc \
--with-config-file-scan-dir=/usr/local/php/etc/conf.d \
--with-pic \
--enable-fpm \
--with-fpm-user=www-data \
--with-fpm-group=www-data \
\
\
--disable-cgi \
--disable-phpdbg \
--enable-opcache \
--enable-ipv6 \
--enable-ctype \
--enable-dom \
--enable-fileinfo \
--enable-filter \
--enable-mbregex \
--enable-huge-code-pages \
--enable-opcache-jit \
--enable-pdo \
--enable-phar \
--enable-posix \
--enable-session \
--enable-simplexml \
--enable-tokenizer \
--enable-xml \
--with-expat \
--enable-xmlreader \
--enable-xmlwriter \
\
\
--disable-short-tags \
--with-openssl \
--with-system-ciphers \
--with-ftp-ssl \
--with-zlib \
--enable-bcmath \
--with-bz2 \
--enable-calendar \
--with-curl \
--enable-exif \
--enable-gd \
--with-freetype \
--with-avif \
--with-webp \
--with-jpeg \
--with-xpm \
--enable-gd-jis-conv \
--with-gettext \
--with-gmp \
--with-iconv \
--enable-intl \
--enable-mbstring \
--enable-mysqlnd \
--with-mysqlnd-ssl \
--with-mysqli \
--with-pdo-mysql=mysqlnd \
--with-sqlite3 \
--with-pdo-sqlite \
--enable-pcntl \
--with-readline \
--enable-soap \
--enable-sockets \
--enable-sysvmsg \
--enable-sysvsem \
--enable-sysvshm \
--enable-shmop \
--with-zip \
--with-xsl \
--with-tidy \
--with-sodium \
--with-password-argon2 \
--enable-ftp \
--with-capstone \
--with-pear \
--with-pdo-pgsql \
--enable-zend-max-execution-timers \
\
&& make -j$(nproc --all) \
&& sleep 3s \
&& make install \
\
&& cd /usr/local/src \
&& mkdir -p /usr/local/php/etc/conf.d \
&& rm -f /usr/local/php/etc/php-fpm.conf \
&& rm -f /usr/local/php/etc/php-fpm.d/www.conf \
&& rm -f /usr/local/php/lib/php.ini \
&& rm -f /usr/local/php/etc/php.ini \
\
&& mv ./php-fpm.conf /usr/local/php/etc/php-fpm.conf \
&& mv ./www.conf     /usr/local/php/etc/php-fpm.d/www.conf \
&& mv ./php.ini      /usr/local/php/etc/php.ini \
\
&& mv ./composer.phar /usr/local/bin/composer \
&& chmod +x /usr/local/bin/composer \
\
&& mkdir -p /usr/local/php/fpm_pools/www/log \
&& mkdir -p /usr/local/php/var/run \
&& mkdir -p /usr/local/php/var/log \
\
&& chown www-data:www-data /usr/local/bin/composer \
&& chown -R www-data:www-data /usr/local/php \
&& chown -R www-data:www-data /wwwdata \
\
&& /usr/local/php/bin/php -v \
&& /usr/local/php/bin/php -m \
&& /usr/local/bin/composer --version \
&& /usr/local/php/sbin/php-fpm --fpm-config /usr/local/php/etc/php-fpm.conf -t \
\
&& mkdir -p /etc/service/php-fpm \
&& cp /usr/local/src/php-fpm.run /etc/service/php-fpm/run \
&& chmod +x /etc/service/php-fpm/run \
\
\
&& apt -yq --no-install-recommends install python3 python3-venv python3-pip \
&& python3 -m venv /usr/local/markitdown \
&& /usr/local/markitdown/bin/pip install -U pip \
&& /usr/local/markitdown/bin/pip install --no-cache-dir \
'markitdown[pdf,docx,pptx,xlsx,xls]' \
markitdown-ocr \
openai \
&& ln -s /usr/local/markitdown/bin/markitdown /usr/local/bin/markitdown \
&& /usr/local/markitdown/bin/python -c "import markitdown, openai" \
&& /usr/local/markitdown/bin/python -c "from magika import Magika; Magika().identify_bytes(b'# test')" \
&& /usr/local/markitdown/bin/markitdown --list-plugins \
&& /usr/local/markitdown/bin/markitdown --list-plugins | grep -qi ocr \
\
&& apt -y autoremove \
&& apt -y clean \
&& rm -rf /var/lib/apt/lists/* \
\
&& rm -rf  /var/cache/fontconfig/* \
&& rm -rf  /var/cache/apt/archives/*.deb \
&& rm -rf  /usr/share/doc/* \
&& rm -rf  /usr/share/man/* \
\
&& rm -rf /tmp/* \
&& rm -rf /var/tmp/* \
\
&& rm -rf  ~/.cache/* \
\
&& du -h --max-depth=2 /usr/local/openresty | sort -hr \
&& du -h --max-depth=2 /usr/local/php | sort -hr \
&& du -h --max-depth=2 /usr/local/markitdown | sort -hr \
&& du -h --max-depth=2 /wwwdata | sort -hr \
&& rm -rf /usr/local/src/*

EXPOSE 80 443

CMD ["/sbin/my_init"]
