#!/bin/bash
#get current branch
if [ -z "${GIT_BRANCH}" ];then
        export GIT_BRANCH=$(git branch | grep '*' | awk '{print $2}');
fi;

#default k8s namespace
if [ -z "${KUBE_NAMESPACE}" ]; then
        export KUBE_NAMESPACE=${APP_GROUP}-${KUBE_ZONE}-$(echo ${GIT_BRANCH} | tr '/' '-')
fi;

kubectl delete --namespace=${KUBE_NAMESPACE} $(kubectl --namespace=${KUBE_NAMESPACE} get all | grep replicaset.apps | grep "0         0         0" | cut -d' ' -f 1)
