#!/bin/sh

# check if Docker image of app is already built or published

./scripts/check_install.sh

export NPM_LATEST=true

if [ -z "${VERSION}" ];then\
        export VERSION=$(./scripts/version.sh)
fi

if [ -z "${DOCKER_IMAGE}" ]; then
    if [ -z "${APP_ID}" -o -z "${DOCKER_USERNAME}" ]; then
            echo "You must provide all those ENV vars:"
            echo "DOCKER_USERNAME=${DOCKER_USERNAME}"
            echo "APP_ID=${APP_ID}"
            exit 1;
    fi;
    export DOCKER_IMAGE=${DOCKER_USERNAME}/${APP_ID}:${VERSION}
fi;

(docker image inspect ${DOCKER_IMAGE}> /dev/null 2>&1) || (docker manifest inspect ${DOCKER_IMAGE} > /dev/null 2>&1)
