FROM phusion/baseimage:noble-1.0.3

LABEL maintainer="charescape@outlook.com"

ENV TZ="Asia/Shanghai"
ENV MARIADB_VERSION="12.3.3"
ENV KILL_PROCESS_TIMEOUT=60
ENV KILL_ALL_PROCESSES_TIMEOUT=60

COPY ubuntu/24.04/mariadb/12.3/chown-mysql.sh  /etc/my_init.d/
COPY ubuntu/24.04/mariadb/12.3/mariadb-backup.sh  /usr/local/sbin/mariadb-backup.sh
COPY ubuntu/24.04/mariadb/12.3/mariadb-backup-conf.sh  /usr/local/sbin/mariadb-backup-conf.sh
COPY ubuntu/24.04/mariadb/12.3/mariadb12v3.conf  /usr/local/src/
COPY ubuntu/24.04/mariadb/12.3/my.cnf  /usr/local/src/
COPY ubuntu/24.04/mariadb/12.3/mariadb.run  /usr/local/src/

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
&& mkdir -p /wwwdata/mysql/data \
&& mkdir -p /wwwdata/mysql/run \
&& mkdir -p /wwwdata/misc \
&& chown -R www-data:www-data /wwwdata \
\
&& apt -yq --no-install-recommends install tzdata \
build-essential                 \
cmake                           \
pkg-config                      \
ca-certificates                 \
wget                            \
perl                            \
bison                           \
flex                            \
git                             \
libaio-dev                      \
liburing-dev                    \
libnuma-dev                     \
libpam0g-dev                    \
libssl-dev                      \
libkrb5-dev                     \
libcurl4-openssl-dev            \
libncurses-dev                  \
libboost-all-dev                \
libjudy-dev                     \
libxml2-dev                     \
libsnappy-dev                   \
liblzo2-dev                     \
liblz4-dev                      \
liblzma-dev                     \
libbz2-dev                      \
libzstd-dev                     \
libfmt-dev                      \
libpcre2-dev                    \
zlib1g-dev                      \
libstemmer-dev                  \
libmsgpack-dev                  \
libzmq3-dev                     \
unixodbc-dev                    \
libcrack2-dev                   \
\
\
&& chmod +x /etc/my_init.d/chown-mysql.sh \
&& chmod +x /usr/local/sbin/mariadb-backup.sh \
&& chmod +x /usr/local/sbin/mariadb-backup-conf.sh \
\
&& apt -yq --no-install-recommends install zstd shellcheck shfmt jq curl util-linux \
\
&& cd /usr/local/src \
\
&& wget --no-verbose https://archive.mariadb.org/mariadb-${MARIADB_VERSION}/source/mariadb-${MARIADB_VERSION}.tar.gz \
&& wget --no-verbose https://archive.mariadb.org/mariadb-${MARIADB_VERSION}/source/sha256sums.txt \
&& grep "mariadb-${MARIADB_VERSION}.tar.gz\$" sha256sums.txt | awk '{print $1 "  " $2}' | sha256sum --check \
\
&& tar -zxf mariadb-${MARIADB_VERSION}.tar.gz \
\
\
&& mkdir /usr/local/src/mariadb-${MARIADB_VERSION}/build_tmp_dir \
&& cd /usr/local/src/mariadb-${MARIADB_VERSION}/build_tmp_dir \
&& cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo \
-DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
-DMYSQL_DATADIR=/wwwdata/mysql/data \
-DTMPDIR=/tmp \
-DINSTALL_RUNDIR=/wwwdata/mysql/run \
-DINSTALL_UNIX_ADDRDIR=/wwwdata/mysql/run/mysql.sock \
-DWITH_EXTRA_CHARSETS=all \
-DPLUGIN_COLUMNSTORE=NO \
-DCONNECT_WITH_MONGO=OFF \
-DENABLED_LOCAL_INFILE=1 \
-DWITH_URING=ON \
-DWITH_NUMA=ON \
-DWITH_LIBAIO=OFF \
-DWITH_ROCKSDB_ZSTD=ON \
-DWITH_INNODB_AHI=ON \
-DWITH_MARIABACKUP=ON \
-DWITH_SYSTEMD=no \
-DWITH_SSL=system \
-DWITH_LIBFMT=system \
-DWITH_PCRE=system \
-DWITH_ZLIB=system \
-DWITH_UNIT_TESTS=0 \
\
\
&& make -j$(nproc --all) \
&& sleep 3s \
&& make install \
\
\
&& cd /usr/local/src \
&& rm -f       /etc/my.cnf \
&& rm -f       /etc/mysql/my.cnf \
&& rm -f       /root/.my.cnf \
\
\
&& cp       ./my.cnf          /etc/my.cnf \
&& cp       ./mariadb12v3.conf  /etc/mariadb12v3.conf.default \
&& cp       ./mariadb12v3.conf  /wwwdata/misc/mariadb12v3.conf \
&& chown -R www-data:www-data /etc/my.cnf \
&& chown -R www-data:www-data /usr/local/mysql \
&& chown -R www-data:www-data /wwwdata \
&& /usr/local/mysql/scripts/mariadb-install-db --defaults-file=/etc/my.cnf --user=www-data --basedir=/usr/local/mysql --datadir=/wwwdata/mysql/data --skip-name-resolve \
\
&& chown -R www-data:www-data /usr/local/mysql \
&& chown -R www-data:www-data /wwwdata \
\
&& mkdir -p /etc/service/mariadb \
&& cp /usr/local/src/mariadb.run /etc/service/mariadb/run \
&& chmod +x /etc/service/mariadb/run \
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
&& rm -rf /usr/local/mysql/mysql-test/* \
&& rm -rf /usr/local/mysql/mariadb-test/* \
&& du -h --max-depth=2 /usr/local/mysql | sort -hr \
&& du -h --max-depth=2 /wwwdata/mysql | sort -hr \
&& rm -rf /usr/local/src/*

EXPOSE 3306

CMD ["/sbin/my_init"]

