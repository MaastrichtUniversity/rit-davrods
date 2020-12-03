FROM centos:7

ARG ENV_DAVRODS_IRODS_VERSION
ARG ENV_DAVRODS_VERSION

RUN yum install -y \
    # Add EPEL repository to download extra packages
    epel-release

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
ARG irods_version=${ENV_DAVRODS_IRODS_VERSION}
RUN rpm --import https://packages.irods.org/irods-signing-key.asc \
    && wget -qO - https://packages.irods.org/renci-irods.yum.repo | tee /etc/yum.repos.d/renci-irods.yum.repo \
    && yum install -y \
    irods-runtime-${irods_version} \
    irods-icommands-${irods_version}

# install Davrods
ARG davrods_version=${ENV_DAVRODS_VERSION}
ARG davrods_github_tag=$davrods_version
RUN ( wget https://github.com/UtrechtUniversity/davrods/releases/download/$davrods_github_tag/davrods-$davrods_version-1.rpm )
RUN ( rpm -ivh davrods-$davrods_version-1.rpm )
RUN ( mv /etc/httpd/conf.d/davrods-vhost.conf /etc/httpd/conf.d/davrods-vhost.conf.org )

# cleanup RPMs
RUN ( yum clean all && rm -rf *.rpm )


# the executable 'run-httpd.sh' expects the following files to be provided
# and will move them into proper locations before starting the HTTPd service
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


ARG ENV_FILEBEAT_VERSION

###############################################################################
#                                INSTALLATION FILEBEAT
###############################################################################

RUN wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${ENV_FILEBEAT_VERSION}-x86_64.rpm -O /tmp/filebeat.rpm \
 && rpm -Uvh /tmp/filebeat.rpm
ADD filebeat.yml /etc/filebeat/filebeat.yml
RUN chmod go-w /etc/filebeat/filebeat.yml

EXPOSE 80
CMD ["/opt/run-httpd.sh"]
