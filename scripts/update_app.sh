#!/bin/bash
#set version from package & git / could be git tag instead
if [ -z "${VERSION}" ];then\
        export VERSION="$(cat package.json | jq -r '.version')-$(git rev-parse --short HEAD)"
fi

#perform update
kubectl set image --namespace=${KUBE_NAMESPACE} deployments/${APP_ID}-deployment ${APP_ID}=${DOCKER_USERNAME}/${APP_ID}:${VERSION}
./scripts/wait_services_readiness.sh

# test and rollback if fail
./scripts/test_minimal.sh || (kubectl rollout undo deployments/${APP_ID}-deployment && exit 1)

