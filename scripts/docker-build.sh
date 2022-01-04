#!/bin/bash

# builds Docker image of app if not already built or published
# put it to local kube if minikube or k3s (${K8S} shall be set, then)

./scripts/check_install.sh

export NPM_LATEST=true

if [ -z "${VERSION}" ];then\
        export VERSION=$(./scripts/version.sh)
fi

if [ -z "${APP_ID}" -o -z "${DOCKER_USERNAME}" ]; then
        echo "You must provide all those ENV vars:"
        echo "DOCKER_USERNAME=${DOCKER_USERNAME}"
        echo "APP_ID=${APP_ID}"
        exit 1;
fi;

export DOCKER_IMAGE=${DOCKER_USERNAME}/${APP_ID}:${VERSION}

if [ -z "${DOCKER_TARGET}" ]; then
        export DOCKER_TARGET=production
fi

if [ -z "${DOCKER_FILE}" ]; then
        if [ -f "Dockerfile.${APP_ID}" ]; then
                export DOCKER_FILE="$(pwd)/Dockerfile.${APP_ID}"
        else
                export DOCKER_FILE="$(pwd)/Dockerfile"
        fi;
fi

if ! (./scripts/docker-check.sh); then
        (
                (
                        if (docker build --no-cache --build-arg NPM_LATEST="${NPM_LATEST}" -f ${DOCKER_FILE} --target ${DOCKER_TARGET} -t ${DOCKER_IMAGE} .) ; then
                                echo -n ""
                        fi;
                ) | stdbuf -o0 grep Step | stdbuf -o0 sed 's/ :.*//' | stdbuf -o0 awk '{ printf "\033[2K\r🐋  Docker build version '${VERSION}' " $0 }';
        ) 3>&1 1>&2 2>&3 3>&- | stdbuf -o0 awk '{ if (/non-zero/) { printf "\033[2K\r\033[31m❌  Docker build failed '${VERSION}'\033[0m\n" $0; exit 1} else {print $0}}'
fi;
if [ $? -eq 0 ]; then
	echo -e "\033[2K\r🐋  Docker successfully built version ${VERSION}";
else
        exit 1;
fi;
