FROM debian:latest

# install dependencies
RUN apt-get update && apt-get install -y \
    sudo make gcc dnsmasq dnsutils unzip php-fpm mariadb-server \
    php7.4-mysql openjdk-17-jre-headless openjdk-17-jre default-jdk \
    libpcre3 libpcre3-dev libexpat1 libexpat1-dev \
    libxml2 libxml2-dev libxslt1-dev libxslt1.1 git \
    curl vim wget \
    && rm -rf /var/lib/apt/lists/*

# download, configure & compile openssl source w/ weak ciphers
RUN mkdir /openssl && \
    curl -SL https://www.openssl.org/source/openssl-1.0.2q.tar.gz \
    | tar -xzC /openssl --strip-components=1

RUN cd /openssl && \
    ./config --prefix=/opt/openssl-1.0.2 --openssldir=/etc/ssl \
    shared enable-weak-ssl-ciphers enable-ssl3 enable-ssl3-method \
    enable-ssl2 -Wl,-rpath=/opt/openssl-1.0.2/lib && \
    make && make install

# add /opt/openssl-1.0.2/lib to /etc/ld.so.conf.d/x86_64-linux-gnu.conf
# NOTE: using sed is probably better for this
RUN echo "# custom OpenSSL" | cat - /etc/ld.so.conf.d/x86_64-linux-gnu.conf > temp \
    && mv temp /etc/ld.so.conf.d/x86_64-linux-gnu.conf
RUN echo "/opt/openssl-1.0.2/lib" | cat - /etc/ld.so.conf.d/x86_64-linux-gnu.conf > temp \
    && mv temp /etc/ld.so.conf.d/x86_64-linux-gnu.conf

RUN ldconfig

# download, configure, build & install apache
# NOTE: need to handle version numbers somehow, even if they're just defined at
# the top of the document as a variable or loaded externally
WORKDIR /root

RUN curl -o httpd.tar.gz https://dlcdn.apache.org/httpd/httpd-2.4.56.tar.gz \
    && curl -o apr.tar.gz https://dlcdn.apache.org//apr/apr-1.7.2.tar.gz \
    && curl -o apr-util.tar.gz https://dlcdn.apache.org//apr/apr-util-1.6.3.tar.gz \
    && tar -xzvf /root/httpd.tar.gz \
    && mv httpd-* httpd

WORKDIR /root/httpd/srclib/

RUN tar -xzvf /root/apr.tar.gz \
    && tar -xzvf /root/apr-util.tar.gz \
    && ln -s apr-1.7.2 apr \
    && ln -s apr-util-1.6.3 apr-util \
    && rm -rf /root/*.tar.gz

WORKDIR /root/httpd/

RUN ./configure --prefix=/opt/apache \
    --with-included-apr \
    --with-ssl=/opt/openssl-1.0.2 \
    --enable-ssl \
    && make && make install

# download DNAS repo & put files where they belong + fix permissions
WORKDIR /root

RUN git clone https://github.com/corbin-ch/DNASrep.git \
    && mv DNASrep/etc/dnas /etc/dnas \
    && chown -R 0:0 /etc/dnas \
    && mkdir /var/www \
    && mv DNASrep/www/dnas /var/www/dnas \
    && chown -R www-data:www-data /var/www/dnas

# download, configure, and build outbreak file 1 & 2 servers
RUN git clone https://github.com/corbin-ch/bioserver.git

WORKDIR /root/bioserver/

RUN mkdir /var/www/bhof1 \
    && mkdir /var/www/bhof2 \
    && cp bioserv1/www/* /var/www/bhof1 \
    && cp bioserv2/www/* /var/www/bhof2 \
    && chown -R www-data:www-data /var/www/bhof1 \
    && chown -R www-data:www-data /var/www/bhof2 \
    && ln -s /var/www/bhof1 /var/www/dnas/00000002 \
    && ln -s /var/www/bhof2 /var/www/dnas/00000010

# NOTE: another version to pay attention to
RUN wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j_8.0.32-1debian11_all.deb \
    && dpkg --install mysql-connector-j_8.0.32-1debian11_all.deb

# building the file 1 server
WORKDIR /root/bioserver/bioserv1/bioserver

RUN javac -cp /usr/share/java/mysql-connector-j-8.0.32.jar:. *.java

WORKDIR /root/bioserver/bioserv1

RUN mkdir bin \
    && mkdir bin/bioserver \
    && mv bioserver/*.class bin/bioserver \
    && mv bioserver/config.properties . \
    && mkdir lib \
    && ln -s /usr/share/java/mysql-connector-j-8.0.32.jar lib/mysql-connector.jar

# building the file 2 server
WORKDIR /root/bioserver/bioserv2/bioserver

RUN javac -cp /usr/share/java/mysql-connector-j-8.0.32.jar:. *.java

WORKDIR /root/bioserver/bioserv2

RUN mkdir bin \
    && mkdir bin/bioserver \
    && mv bioserver/*.class bin/bioserver \
    && mv bioserver/config.properties . \
    && mkdir lib \
    && ln -s /usr/share/java/mysql-connector-j-8.0.32.jar lib/mysql-connector.jar

# need a place for php-fpm7.4's socket
RUN mkdir /run/php/ \
    && chown www-data:www-data /run/php \
    && chmod 755 /run/php

# copy config files into the container
COPY ./config/entrypoint.sh /root/
COPY ./config/obcomsrv /etc/dnsmasq.d/
COPY ./config/end_of_httpd.conf /root/

# possibly some extra ports here but i believe the 8xxx ports are required for outbreak
EXPOSE 53
EXPOSE 80
EXPOSE 443
EXPOSE 8200
EXPOSE 8300
EXPOSE 8590
EXPOSE 8690

ENTRYPOINT ["/bin/bash", "/root/entrypoint.sh"]

# i might want to use CMD ["start_services.sh"] or something rather than sticking it in the entrypoint
CMD ["/bin/bash"]
