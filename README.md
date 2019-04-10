## RIT-Davrods
This is the Research IT version of Davrods. It is based on:
* the original Davrods software from [Utrecht University](https://github.com/UtrechtUniversity/davrods)
* the Docker container from [Donders Institute](https://github.com/donders-research-data-management/rdm-docker-davrods/tree/master/davrods)

### Run instructions for docker-compose
First, create an `.env` file in the root of your workdir, based on this example:
```
ENV_DAVRODS_IRODS_VERSION=4.2.5
ENV_DAVRODS_VERSION=4.2.5_1.4.2
```

Then add a `docker-compose.yml` file based on this example:
```
version: '2'
services:
  davrods:
    build:
      context: externals/rit-davrods/
      args:
        - ENV_DAVRODS_IRODS_VERSION
        - ENV_DAVRODS_VERSION
```

Edit the `config/davrods-vhost.conf` file and enter values that correspond to your iRODS environment. Especially look for these variables
```
ServerName
DavRodsServer
DavRodsZone
DavRodsAuthScheme
DavRodsExposedRoot
```

Finally, build and run the container
```
docker-compose build davrods
docker-compose up -d davrods
```