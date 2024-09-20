#!/bin/bash

if [ -f /config/davrods-vhost.conf ]; then
    if [ -f /etc/apache2/sites-available/davrods-vhost.conf ]; then
        cp /etc/apache2/sites-available/davrods-vhost.conf /etc/apache2/sites-available/davrods-vhost.conf.org
    fi
    cp /config/davrods-vhost.conf /etc/apache2/sites-available/davrods-vhost.conf
    chmod 0644 /etc/apache2/sites-available/davrods-vhost.conf
fi

if [ -f /config/irods_environment.json ]; then
    cp /config/irods_environment.json /etc/apache2/irods/irods_environment.json
    chmod 0644 /etc/apache2/irods/irods_environment.json
fi

# Start filebeat
/etc/init.d/filebeat start

# start the apache daemon
exec /usr/sbin/apachectl -DFOREGROUND

# this script must end with a persistent foreground process
tail -F /var/log/apache2/apache.access.log /var/log/apache2/apache.error.log
