FROM debian:9.2

LABEL maintainer="rajeev.rai.4283@gmail.com"

ENV ARCH="amd64"
ENV DEBIAN_FRONTEND=noninteractive
ENV GOSU_VERSION="1.10"
ENV PYTHON_EGG_CACHE="/tmp/.python-eggs"
ENV SHELL="/bin/bash"
ENV TZ="/Asia/Kolkata"
ENV VERTICA_DIR="/vertica"
ENV VERTICA_CATALOG="/vertica/catalog"
ENV VERTICA_CONFIG="/vertica/config"
ENV VERTICA_DATA="/vertica/data"

WORKDIR /tmp/

RUN set -eux && \
    echo "Installing dependencies" && \
    apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y openssh-server pstack mcelog gdb sysstat dialog ntp tzdata locales wget && \
    \
    echo "Installing gosu" && \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$ARCH" && \
    chmod +x /usr/local/bin/gosu && \
    \
    echo "Installing dumb-init" && \
    wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.1/dumb-init_1.2.1_amd64 && \
    chmod +x /usr/local/bin/dumb-init && \
    \
    echo "Setting Locales" && \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure locales && \
    update-locale LANG=en_US.UTF-8 && \
    \
    echo "Adding vertica user/group" && \
    groupadd -r verticadba && \
    useradd -r -m -g verticadba dbadmin && \
    chsh -s /bin/bash dbadmin && \
    chsh -s /bin/bash root && \
    echo "dbadmin - nice 0" >> /etc/security/limits.conf && \
    echo "dbadmin - nofile 65536" >> /etc/security/limits.conf && \
    \
    echo "Setting TimeZone" && \
    echo "export TZ='$TZ'" >> /home/dbadmin/.bashrc && \
    \
    echo "Fetching vertica" && \
    wget "https://s3.ap-south-1.amazonaws.com/rzp-artifacts/packages/ubuntu/14.04/vertica_9.1.0.deb" && \
    \
    echo "Unpacking vertica" && \
    dpkg -i /tmp/vertica_9.1.0.deb && \
    \
    echo "Installing vertica" && \
    /opt/vertica/sbin/install_vertica --license CE --accept-eula --hosts 127.0.0.1 --dba-user-password-disabled --failure-threshold NONE --no-system-configuration --ignore-install-config && \
    \
    mkdir -p $VERTICA_DIR $PYTHON_EGG_CACHE && \
    chown -R dbadmin:verticadba $VERTICA_DIR /opt/vertica/log/ $PYTHON_EGG_CACHE && \
    \
    echo "Cleaning..." && \
    rm -f /tmp/vertica_9.1.0.deb && \
    apt-get clean

VOLUME /vertica

ADD ./entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 5433
