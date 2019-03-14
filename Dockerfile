FROM ubuntu:18.04 as build
MAINTAINER Chaim Sanders chaim.sanders@gmail.com

# Install Prereqs
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update -qq && \
    apt-get install -qq -y --no-install-recommends --no-install-suggests \
      apache2             \
      apache2-dev         \
      ca-certificates     \
      automake            \
      libcurl4-gnutls-dev \
      libpcre++-dev       \
      libtool             \
      libxml2-dev         \
      libyajl-dev         \
      lua5.2-dev          \
      pkgconf             \
      ssdeep              \
      wget            &&  \
    apt-get clean && rm -rf /var/lib/apt/lists/* 

# Download ModSecurity & compile ModSecurity
RUN mkdir -p /usr/share/ModSecurity && cd /usr/share/ModSecurity && \
    wget --quiet "https://github.com/SpiderLabs/ModSecurity/releases/download/v2.9.2/modsecurity-2.9.2.tar.gz" && \
    tar -xvzf modsecurity-2.9.2.tar.gz && cd /usr/share/ModSecurity/modsecurity-2.9.2/ && \
    ./autogen.sh && ./configure && \
    make && make install && make clean

FROM ubuntu:18.04

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update -qq && \
    apt-get install -qq -y --no-install-recommends --no-install-suggests \
      apache2             \
      libcurl3-gnutls     \
      libxml2             \
      libyajl2            \
      ssdeep           && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    mkdir -p /etc/apache2/modsecurity.d 

COPY --from=build /usr/lib/apache2/modules/mod_security2.so                              /usr/lib/apache2/modules/mod_security2.so
COPY --from=build /usr/share/ModSecurity/modsecurity-2.9.2/modsecurity.conf-recommended  /etc/apache2/modsecurity.d/modsecurity.conf
COPY --from=build /usr/share/ModSecurity/modsecurity-2.9.2/unicode.mapping               /etc/apache2/modsecurity.d/unicode.mapping

RUN sed -i -e 's/ServerSignature On/ServerSignature Off/g' \
           -e 's/ServerTokens OS/ServerTokens Prod/g'  /etc/apache2/conf-enabled/security.conf && \
    echo "Include modsecurity.d/*.conf"                                          > /etc/apache2/mods-available/modsecurity.conf && \
    echo "LoadModule security2_module /usr/lib/apache2/modules/mod_security2.so" > /etc/apache2/mods-available/modsecurity.load && \
    echo 'ServerName localhost' >>  /etc/apache2/conf-enabled/security.conf && \
    echo "hello world" > /var/www/html/index.html && \
    a2enmod unique_id modsecurity && \
    apt update && \
    apt install -y git nano curl ca-certificates && \
    apt-get install libapache2-mod-security2 && \
    mv /etc/modsecurity/modsecurity.conf-recommended  modsecurity.conf && \
    apt-cache show libapache2-mod-security2 && \
    cd ~ && \ 
    git clone https://github.com/SpiderLabs/owasp-modsecurity-crs.git && \
    cd owasp-modsecurity-crs && \
    mv crs-setup.conf.example /etc/modsecurity/crs-setup.conf && \
    mv rules/ /etc/modsecurity/


EXPOSE 80

CMD ["apachectl", "-D", "FOREGROUND"]
