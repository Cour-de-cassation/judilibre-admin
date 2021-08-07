#!/bin/bash
#set version from package & git / could be git tag instead
if [ -z "${VERSION}" ];then\
        export VERSION="$(cat package.json | jq -r '.version')-$(git rev-parse --short HEAD)"
fi

#get current branch
if [ -z "${GIT_BRANCH}" ];then
        export GIT_BRANCH=$(git branch | grep '*' | awk '{print $2}');
fi;

#default k8s namespace
if [ -z "${KUBE_NAMESPACE}" ]; then
        export KUBE_NAMESPACE=${APP_GROUP}-${KUBE_ZONE}-$(echo ${GIT_BRANCH} | tr '/' '-')
fi;

#perform update
kubectl set image --namespace=${KUBE_NAMESPACE} deployments/${APP_ID}-deployment ${APP_ID}=${DOCKER_USERNAME}/${APP_ID}:${VERSION}
./scripts/wait_services_readiness.sh

# test and rollback if fail
./scripts/test_minimal.sh || (kubectl rollout undo deployments/${APP_ID}-deployment && exit 1)

