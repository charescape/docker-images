FROM phusion/baseimage:noble-1.0.3

LABEL maintainer="charescape@outlook.com"

ENV TZ="Asia/Shanghai"
ENV JAVA_VERSION="21.0.12.1_1"
ENV JAVA_HASH="ce79869e1307ed8ee1e2baa86a412b1eb5b75d10a01006d788a6f968bcfaee94"
ENV MAVEN_VERSION="3.9.16"
ENV MAVEN_HASH="831a8591fe20c8243b1dbe7d71e3244f31d1665b0804b2e825e38cbbe5ce0cafb8338851f90780735568773e0a6cd07bbec107cda0b896b008b861075358b6f6"
ENV JAVA_HOME="/usr/local/jdk"
ENV MAVEN_HOME="/usr/local/maven"
ENV JAVA_OPTS="-Xms256m -Xmx1g -Djava.awt.headless=true"
ENV KILL_PROCESS_TIMEOUT=60
ENV KILL_ALL_PROCESSES_TIMEOUT=60
ENV PATH="/usr/local/jdk/bin:/usr/local/maven/bin:${PATH}"

COPY ubuntu/24.04/java/21.0/chown-java.sh  /etc/my_init.d/
COPY ubuntu/24.04/java/21.0/java.run  /usr/local/src/
COPY ubuntu/24.04/java/21.0/settings.xml  /usr/local/src/

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
&& mkdir -p /wwwdata/java/m2 \
&& mkdir -p /wwwdata/java/logs \
&& mkdir -p /wwwdata/java/tmp \
&& mkdir -p /wwwdata/misc \
&& chown -R www-data:www-data /wwwdata \
\
&& apt -yq --no-install-recommends install tzdata \
ca-certificates                 \
wget                            \
fontconfig                      \
libfreetype6                    \
libxrender1                     \
libxtst6                        \
libxi6                          \
fonts-noto-cjk                  \
fonts-wqy-microhei              \
fonts-wqy-zenhei                \
\
\
&& chmod +x /etc/my_init.d/chown-java.sh \
\
&& apt -yq --no-install-recommends install zstd shellcheck shfmt jq curl util-linux \
\
&& cd /usr/local/src \
\
&& wget --no-verbose -O OpenJDK21U-jdk_x64_linux_hotspot_${JAVA_VERSION}.tar.gz \
https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_linux_hotspot_${JAVA_VERSION}.tar.gz \
&& echo "${JAVA_HASH} *OpenJDK21U-jdk_x64_linux_hotspot_${JAVA_VERSION}.tar.gz" | sha256sum --check \
\
&& tar -zxf OpenJDK21U-jdk_x64_linux_hotspot_${JAVA_VERSION}.tar.gz \
&& mv jdk-21.0.12.1+1 /usr/local/jdk \
\
&& wget --no-verbose -O apache-maven-${MAVEN_VERSION}-bin.tar.gz \
https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
&& echo "${MAVEN_HASH} *apache-maven-${MAVEN_VERSION}-bin.tar.gz" | sha512sum --check \
\
&& tar -zxf apache-maven-${MAVEN_VERSION}-bin.tar.gz \
&& mv apache-maven-${MAVEN_VERSION} /usr/local/maven \
&& cp /usr/local/src/settings.xml /usr/local/maven/conf/settings.xml \
\
\
&& chown -R www-data:www-data /wwwdata \
\
&& /usr/local/jdk/bin/java -version \
&& /usr/local/jdk/bin/javac -version \
&& /usr/local/maven/bin/mvn -version \
\
\
&& mkdir -p /etc/service/java \
&& cp /usr/local/src/java.run /etc/service/java/run \
&& chmod +x /etc/service/java/run \
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
&& fc-cache -f \
\
&& du -h --max-depth=2 /usr/local/jdk | sort -hr \
&& du -h --max-depth=2 /usr/local/maven | sort -hr \
&& du -h --max-depth=2 /wwwdata/java | sort -hr \
&& rm -rf /usr/local/src/*

EXPOSE 8080

CMD ["/sbin/my_init"]
