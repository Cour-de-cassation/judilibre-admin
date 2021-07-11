#!/bin/sh

if [ -z ${ELASTIC_DUMP} ]; then
    echo "Please provide path path of json dump in ELASTIC_DUMP" && exit 1;
fi

if ! (cat ${ELASTIC_DUMP} | jq -cr '."_index"' | head -1 | grep -q judilibre_); then
    echo "${ELASTIC_DUMP} doesnt seem to be an index dump" && exit 1;
fi

if ! (which elasticdump > /dev/null 2>&1);then
    sudo npm install -g elasticdump;
fi;
export NODE_TLS_REJECT_UNAUTHORIZED=0
ES_PWD=$(kubectl get secret --namespace=${KUBE_NAMESPACE} judilibre-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')
kubectl port-forward --namespace=${KUBE_NAMESPACE} service/judilibre-es-http 9200 &
elasticdump --output=https://elastic:${ES_PWD}@localhost:9200/judilibre_0 --type=data --input=${ELASTIC_DUMP}
ps -lef | grep 'kubectl port-forward' | head -1 | awk '{print $4}' | xargs kill
