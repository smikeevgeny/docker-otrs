FROM ubuntu:16.04
MAINTAINER Tommaso Visconti <tommaso.visconti@gmail.com>
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -qq update && apt-get install -y wget apache2 supervisor libcrypt-ssleay-perl libencode-hanextra-perl libgd-gd2-perl libgd-text-perl libgd-graph-perl libjson-xs-perl liblwp-useragent-determined-perl libmail-imapclient-perl libapache2-mod-perl2 libnet-dns-perl libnet-ldap-perl libpdf-api2-perl libtext-csv-xs-perl libxml-parser-perl libyaml-perl libcrypt-eksblowfish-perl libyaml-libyaml-perl libnet-ldap-perl mysql-server fetchmail

# Supervisor
RUN mkdir -p /var/log/supervisor
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Begin MySQL server setup
RUN sed -i -e"s/^key_buffer\s*=\s*16M/key_buffer_size=32M/" /etc/mysql/my.cnf
RUN sed -i -e"s/^max_allowed_packet\s*=\s*16M/max_allowed_packet=32M/" /etc/mysql/my.cnf
RUN sed -i -e"s/^bind-address\s*=\s*0.0.0.0/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf

ADD otrs/database.sql /root/database.sql
ADD init_db.sh /tmp/init_db.sh
RUN chmod +x /tmp/init_db.sh 
RUN /tmp/init_db.sh
# End MySQL server setup

# OTRS
RUN wget http://ftp.otrs.org/pub/otrs/otrs-5.0.15.tar.gz
RUN tar -C /opt -xzf ./otrs-5.0.15.tar.gz && rm ./otrs-5.0.15.tar.gz && mv /opt/otrs-5.0.15 /opt/otrs
RUN useradd -r -d /opt/otrs -c 'OTRS service user' otrsserviceuser
RUN usermod -G nogroup otrsserviceuser
ADD otrs/Config.pm /opt/otrs/Kernel/Config.pm

RUN cd /opt/otrs/var/cron && for foo in *.dist; do cp $foo `basename $foo .dist`; done
RUN cd /opt/otrs/bin && ./otrs.SetPermissions.pl /opt/otrs --otrs-user=otrsserviceuser --otrs-group=nogroup --web-user=www-data --web-group=www-data
RUN ln -s /opt/otrs/scripts/apache2-httpd.include.conf /etc/apache2/conf-enabled/otrs.conf

# ITSM with MySQL server
RUN /usr/sbin/mysqld & \
    sleep 15s &&\
    cd /opt/otrs && wget http://ftp.otrs.org/pub/otrs/itsm/bundle5/ITSM-5.0.15.opm && chown otrsserviceuser:nogroup /opt/otrs/ITSM-5.0.15.opm && su otrsserviceuser -c "/opt/otrs/bin/otrs.PackageManager.pl -a install -p /opt/otrs/ITSM-5.0.15.opm" && rm /opt/otrs/ITSM-5.0.15.opm && cd /opt/otrs/bin && ./otrs.SetPermissions.pl /opt/otrs --otrs-user=otrsserviceuser --otrs-group=nogroup --web-user=www-data --web-group=www-data

# ITSM without MySQL server
# RUN cd /opt/otrs && wget http://ftp.otrs.org/pub/otrs/itsm/bundle5/ITSM-5.0.15.opm && chown otrsserviceuser:nogroup /opt/otrs/ITSM-5.0.15.opm && su otrsserviceuser -c "/opt/otrs/bin/otrs.PackageManager.pl -a install -p /opt/otrs/ITSM-3.3.7.opm" && rm /opt/otrs/ITSM-3.3.7.opm && cd /opt/otrs/bin && ./otrs.SetPermissions.pl /opt/otrs --otrs-user=otrsserviceuser --otrs-group=nogroup --web-user=www-data --web-group=www-data

# Set OTRS cron jobs
su otrsserviceuser -c "/opt/otrs/bin/Cron.sh start"

# Begin SSH server setup
ENV ROOT_PWD s3cr3t
RUN apt-get install -y openssh-server pwgen
RUN mkdir -p /var/run/sshd
ADD sshd_config /etc/ssh/sshd_config
RUN echo "root:$ROOT_PWD" | chpasswd
# End SSH server setup

RUN apt-get clean && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

EXPOSE 22 80

CMD ["/usr/bin/supervisord"]
