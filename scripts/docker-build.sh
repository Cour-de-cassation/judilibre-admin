#!/bin/bash
(docker image inspect ${DOCKER_USERNAME}/${APP_ID}:${VERSION} > /dev/null 2>&1) && echo "🐋  Docker image is present locally" || \
        (docker build --no-cache --build-arg API_PORT=${API_PORT} --target production -t ${DOCKER_USERNAME}/${APP_ID}:${VERSION} . 2>&1 \
                 | stdbuf -o0 grep Step | stdbuf -o0 sed 's/ :.*//' | awk  '{printf "\033[2K\r🐋  Docker build " $0}' && echo -e "\033[2K\r🐋  Docker is now built")
