#!/bin/sh

if ! (which elasticdump > /dev/null 2>&1);then
    sudo npm install -g elasticdump;
fi;

ES_PWD=$(kubectl get secret --namespace=${KUBE_NAMESPACE} judilibre-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')
kubectl port-forward --namespace=${KUBE_NAMESPACE} service/judilibre-es-http 9200 &
elasticdump --input=https://elastic:${ES_PWD}@localhost:9200/judilibre_0 --type=data --output=$(date +%Y%m%d)_judilibre_0_index.json
ps -lef | grep 'kubectl port-forward' | head -1 | awk '{print $4}' | xargs kill
