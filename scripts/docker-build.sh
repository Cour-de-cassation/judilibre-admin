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

if ! (./scripts/docker-check.sh); then
        (docker build --no-cache --build-arg API_PORT=${API_PORT} --build-arg NPM_LATEST=${NPM_LATEST} --target production -t ${DOCKER_IMAGE} . \
                | stdbuf -o0 grep Step | stdbuf -o0 sed 's/ :.*//' | awk  '{printf "\033[2K\r🐋  Docker build " $0}' && \
        echo -e "\033[2K\r🐋  Docker successfully built");
fi;
