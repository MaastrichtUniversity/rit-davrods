# This build-stage-image contains irods-dev, thus containing clang, which is a huge package. Separated it from the main image to minimize size
FROM ubuntu:22.04 AS build

ARG ENV_DAVRODS_IRODS_VERSION
ARG ENV_IRODS_VERSION

RUN apt update
RUN apt install -y \
    apache2-dev \
    git \
    wget \
    cmake
    
RUN wget -qO - https://packages.irods.org/irods-signing-key.asc | apt-key add - \
    && echo "deb [arch=amd64] https://packages.irods.org/apt/ jammy main" | tee /etc/apt/sources.list.d/renci-irods.list \
    && apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -y \
    irods-runtime=${ENV_IRODS_VERSION} \
    irods-dev=${ENV_IRODS_VERSION} 

# Clone the Utrecht University Davrods repository
WORKDIR /tmp
RUN git clone https://github.com/UtrechtUniversity/davrods.git
WORKDIR /tmp/davrods
RUN git checkout c3d7b98878d8fd823f24bcbc5bca2928f4e8a100
WORKDIR /tmp
RUN mkdir -p /tmp/davrods/build

# Update iRODS version in CMakeLists file
RUN sed -i 's/${ENV_DAVRODS_IRODS_VERSION}/4.3.2/g' /tmp/davrods/CMakeLists.txt
# Build Davrods for our iRODS version
WORKDIR /tmp/davrods/build
RUN cmake ..
RUN make

# Actual image below
FROM ubuntu:22.04

ARG ENV_DAVRODS_IRODS_VERSION
ARG ENV_DAVRODS_VERSION
ARG ENV_IRODS_VERSION

# Install dependencies
RUN apt update
RUN apt install -y \
    wget \
    nano \
    gnupg2 \
    apache2 \
    libapache2-mod-security2

# Install Filebeat
ARG FILEBEAT_CONFIG_FILE
ARG ENV_FILEBEAT_VERSION
RUN wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${ENV_FILEBEAT_VERSION}-amd64.deb -O /tmp/filebeat.deb \
 && dpkg -i /tmp/filebeat.deb
ADD config/${FILEBEAT_CONFIG_FILE} /etc/filebeat/filebeat.yml
RUN chmod go-w /etc/filebeat/filebeat.yml

# Install iRODS runtime and icommands
# We install the version that is currently running in acc/prod
RUN wget -qO - https://packages.irods.org/irods-signing-key.asc | apt-key add - \
    && echo "deb [arch=amd64] https://packages.irods.org/apt/ jammy main" | tee /etc/apt/sources.list.d/renci-irods.list \
    && apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -y \
    irods-runtime=${ENV_IRODS_VERSION} \
    irods-icommands=${ENV_IRODS_VERSION}


# Download and install davrods
# We install the latest version of davrods, even though it does not match our iRODS version
# This should be fine to run like this (see https://github.com/UtrechtUniversity/davrods?tab=readme-ov-file#download)
RUN wget https://github.com/UtrechtUniversity/davrods/releases/download/${ENV_DAVRODS_IRODS_VERSION}_${ENV_DAVRODS_VERSION}/davrods-${ENV_DAVRODS_IRODS_VERSION}-${ENV_DAVRODS_VERSION}.deb -O /tmp/davrods.deb \
    && dpkg -i --force-depends /tmp/davrods.deb


# the executable 'run-httpd.sh' expects the following files to be provided
# and will move them into proper locations before starting the HTTPd service
#
# The expected files:
#   - davrods-vhost.conf: the Apache configuration for the WebDAV vhost
#   - irods_environment.json: runtime environment of iRODS
ARG VHOST_FILE
ADD config/${VHOST_FILE} /config/davrods-vhost.conf
ADD config/irods_environment.json /config/irods_environment.json

# Conditionally trust the custom DataHub *Dev/Test-only* Certificate Authority (CA) for iRODS-SSL-connections
ADD config/test_only_dev_irods_dh_ca_cert.pem /tmp/test_only_dev_irods_dh_ca_cert.pem
ARG SSL_ENV
# Note: Python docker image is Debian-based. So, 'dash' as /bin/sh.
#       Strict POSIX-compliant.
RUN if [ $SSL_ENV != "acc" ] && [ $SSL_ENV != "prod" ]; then \
        echo "Adding custom DataHub iRODS-CA-certificate to the CA-rootstore (FOR DEV & TEST ONLY!)..." ; \
        cp /tmp/test_only_dev_irods_dh_ca_cert.pem /usr/local/share/ca-certificates/test_only_dev_irods_dh_ca_cert.crt ; \
        update-ca-certificates ; \
    else \
        echo "Not in dev environment: Skipping update of the CA-rootstore" ; \
    fi


# apache2 config
COPY run-httpd.sh /opt/run-httpd.sh
RUN ( chmod +x /opt/run-httpd.sh )
RUN sed -ri \
        -e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' \
        -e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' \
        "/etc/apache2/apache2.conf"

# Add security2_module config to replace "Server: Apache" header to "Server: DataHub"
COPY config/security2_module.conf /tmp/security2_module.conf
RUN cat tmp/security2_module.conf >> /etc/apache2/apache2.conf

# Add allowed request methods
ARG ALLOWED_METHODS_FILE
COPY config/${ALLOWED_METHODS_FILE} /etc/apache2/conf-available/${ALLOWED_METHODS_FILE}
RUN ln -s /etc/apache2/conf-available/${ALLOWED_METHODS_FILE} /etc/apache2/conf-enabled/${ALLOWED_METHODS_FILE}

# Enable 'davrods' in Apache2
RUN a2enmod davrods
# Add customized davrods executable to be used with iRODS 4.3.2 runtime currently installed
COPY --from=build /tmp/davrods/build/mod_davrods.so /usr/lib/apache2/modules/mod_davrods.so

EXPOSE 80
CMD ["/opt/run-httpd.sh"]
