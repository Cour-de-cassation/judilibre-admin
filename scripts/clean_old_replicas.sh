#!/bin/bash
#get current branch
if [ -z "${GIT_BRANCH}" ];then
        export GIT_BRANCH=$(git branch | grep '*' | awk '{print $2}');
fi;

#default k8s namespace
if [ -z "${KUBE_NAMESPACE}" ]; then
        export KUBE_NAMESPACE=${APP_GROUP}-${KUBE_ZONE}-$(echo ${GIT_BRANCH} | tr '/' '-')
fi;

PODS_TO_DELETE=$(kubectl --namespace=${KUBE_NAMESPACE} get all | grep replicaset.apps | grep "0         0         0" | cut -d' ' -f 1)

if [ -z "${PODS_TO_DELETE}" ];then echo "no pods to delete" && exit 0;fi

kubectl delete --namespace=${KUBE_NAMESPACE} ${PODS_TO_DELETE}
