FROM centos:7

# install required packages
RUN ( yum -y install wget nano \
                     git zlib \
                     openssl openssl-libs \
                     boost boost-system boost-filesystem \
                     boost-chrono boost-regex boost-thread \
                     jansson fuse-libs \
                     httpd)

# create temporary directory
RUN ( mkdir -p /tmp )
WORKDIR /tmp

# install iRODS runtime and icommands
ARG irods_version=4.1.12
RUN ( wget ftp://ftp.renci.org/pub/irods/releases/$irods_version/centos7/irods-runtime-$irods_version-centos7-x86_64.rpm )
RUN ( rpm -ivh irods-runtime-$irods_version-centos7-x86_64.rpm )
RUN ( wget ftp://ftp.renci.org/pub/irods/releases/$irods_version/centos7/irods-icommands-$irods_version-centos7-x86_64.rpm )
RUN ( rpm -ivh irods-icommands-$irods_version-centos7-x86_64.rpm )

# install Davrods
ARG davrods_version=4.1_1.1.1
ARG davrods_github_tag=$davrods_version
RUN ( wget https://github.com/UtrechtUniversity/davrods/releases/download/$davrods_github_tag/davrods-$davrods_version-1.el7.centos.x86_64.rpm )
RUN ( rpm -ivh davrods-$davrods_version-1.el7.centos.x86_64.rpm )
RUN ( mv /etc/httpd/conf.d/davrods-vhost.conf /etc/httpd/conf.d/davrods-vhost.conf.org )

# cleanup RPMs
RUN ( yum clean all && rm -rf *.rpm )


# the executable 'run-httpd.sh' expects the following files to be provided
# and will move them into proper locations before starting the HTTPd searvice
#
# The expected files:
#   - davrods-vhost.conf: the Apache configuration for the WebDAV vhost
#   - irods_environment.json: runtime environment of iRODS
ADD config/davrods-vhost.conf /config/davrods-vhost.conf
ADD config/irods_environment.json /config/irods_environment.json

# start httpd
COPY run-httpd.sh /opt/run-httpd.sh
RUN ( chmod +x /opt/run-httpd.sh )

RUN sed -ri \
		-e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' \
		-e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' \
		"/etc/httpd/conf/httpd.conf"

EXPOSE 80
CMD ["/opt/run-httpd.sh"]
