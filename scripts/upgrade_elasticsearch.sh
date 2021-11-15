#!/bin/bash

sudo echo -n

./scripts/check_install.sh

if [ -z "${KUBE_INSTALL_LOG}" ];then
    export KUBE_INSTALL_LOG=$(pwd)/k8s-$(date +%Y%m%d_%H%M).log;
fi;

if [ -z "${KUBECTL}" ];then
    export KUBECTL=$(which kubectl);
fi

if [ -z "${APP_ENV_SPEC}" ];then
        export APP_ENV_SPEC=" "
fi;

if [ "${APP_GROUP}" == "monitor" ];then
        export APP_ENV_SPEC=$(cat <<-APP_ENV_SPEC
- { name: PISTE_JUDILIBRE_KEY, valueFrom: { secretKeyRef: { name: piste-api-keys, key: PISTE_JUDILIBRE_KEY } } }
          - { name: PISTE_JUDILIBRE_KEY_PROD, valueFrom: { secretKeyRef: { name: piste-api-keys, key: PISTE_JUDILIBRE_KEY_PROD } } }
          - { name: PISTE_METRICS_KEY, valueFrom: { secretKeyRef: { name: piste-api-keys, key: PISTE_METRICS_KEY } } }
          - { name: PISTE_METRICS_SECRET, valueFrom: { secretKeyRef: { name: piste-api-keys, key: PISTE_METRICS_SECRET } } }
          - { name: PISTE_METRICS_KEY_PROD, valueFrom: { secretKeyRef: { name: piste-api-keys, key: PISTE_METRICS_KEY_PROD } } }
          - { name: PISTE_METRICS_SECRET_PROD, valueFrom: { secretKeyRef: { name: piste-api-keys, key: PISTE_METRICS_SECRET_PROD } } }
APP_ENV_SPEC
);
fi

#default k8s namespace
if [ -z "${KUBE_NAMESPACE}" ]; then
        export KUBE_NAMESPACE=${APP_GROUP}-${KUBE_ZONE}-$(echo ${GIT_BRANCH} | tr '/' '-')
fi;

if [ ! -z "${SCW_DATA_SECRET_KEY}" ];then
        export SCW_DATA_ACCESS_KEY_B64=$(echo -n ${SCW_DATA_ACCESS_KEY} | openssl base64);
        export SCW_DATA_SECRET_KEY_B64=$(echo -n ${SCW_DATA_SECRET_KEY} | openssl base64);
else
        # dummy keys for local deployment
        export SCW_DATA_ACCESS_KEY_B64=Y2hhbmdlbWU=;
        export SCW_DATA_SECRET_KEY_B64=Y2hhbmdlbWU=;
fi;

: ${SCW_REGION:="fr-par"}

export ELASTIC_ADMIN_PASSWORD=$(${KUBECTL} get secret --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-elastic-user -o go-template='{{.data.elastic | base64decode}}' 2>&1);
export ELASTIC_NODE="https://elastic:${ELASTIC_ADMIN_PASSWORD}@localhost:9200"

ELASTIC_REPOSITORY="{
        'type': 's3',
        'settings': {
                'bucket': '${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}-${KUBE_NAMESPACE}',
                'region': '${SCW_REGION}',
                'endpoint': 's3.${SCW_REGION}.scw.cloud'
        }
}"
ELASTIC_REPOSITORY=$(echo ${ELASTIC_REPOSITORY} | tr "'" '"' | jq -c '.')

if (cat k8s/snapshots.yaml | envsubst "$(perl -e 'print "\$$_" for grep /^[_a-zA-Z]\w*$/, keys %ENV')" | ${KUBECTL} delete -f - >> ${KUBE_INSTALL_LOG} 2>&1); then
        echo "🧹  delete snapshots"
else
        (echo -e "\r\033[2K\e[33m⚠️   stop snapshots\e[0m");
fi;

if (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s --fail -k "${ELASTIC_NODE}/_snapshot/${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}-${KUBE_NAMESPACE}" >> ${KUBE_INSTALL_LOG} 2>&1);then
    if (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k -XDELETE "${ELASTIC_NODE}/_snapshot/${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}-${KUBE_NAMESPACE}" >> ${KUBE_INSTALL_LOG} 2>&1); then
        echo "🧹  delete elasticsearch backup repository";
    else
        (echo -e "\r\033[2K\e[33m⚠️   elasticsearch detach backup repository\e[0m");
    fi;
fi;

if (${KUBECTL} delete secret --namespace=${KUBE_NAMESPACE} ${APP_ID}-es-path-with-auth >> ${KUBE_INSTALL_LOG} 2>&1); then
        echo "🧹  delete secret ${NAMESPACE}/${APP_ID}-es-path-with-auth";
else
        (echo -e "\r\033[2K\e[33m⚠️   delete secret ${NAMESPACE}/${APP_ID}-es-path-with-auth\e[0m");
fi;

if (cat k8s/deployment.yaml | envsubst "$(perl -e 'print "\$$_" for grep /^[_a-zA-Z]\w*$/, keys %ENV')" | ${KUBECTL} delete -f - >> ${KUBE_INSTALL_LOG} 2>&1); then
        echo "🧹  delete ${APP_ID} deployment";
else
        cat k8s/deployment.yaml | envsubst "$(perl -e 'print "\$$_" for grep /^[_a-zA-Z]\w*$/, keys %ENV')" >> ${KUBE_INSTALL_LOG};
        (echo -e "\r\033[2K\e[33m⚠️   delete ${APP_ID} deployment\e[0m");
fi;

if [ "${APP_GROUP}" == "monitor" ];then
        export KUBE_SERVICES_FORCE_UPDATE="elasticsearch-users monitor service deployment"
        if (${KUBECTL} delete -n ${KUBE_NAMESPACE} deployment.apps/logstash-deployment >> ${KUBE_INSTALL_LOG} 2>&1); then
                echo "🧹  delete logstash cluster"
        else
                echo -e "\e[33m⚠️   delete logstash\e[0m";
        fi;
        if (${KUBECTL} delete -n ${KUBE_NAMESPACE} elasticsearch ${APP_GROUP} >> ${KUBE_INSTALL_LOG} 2>&1); then
                echo "🧹  delete elasticsearch cluster"
        else
                echo -e "\e[33m⚠️   delete elasticsearch cluster\e[0m";
        fi;
else
        if (cat k8s/elasticsearch.yaml | envsubst "$(perl -e 'print "\$$_" for grep /^[_a-zA-Z]\w*$/, keys %ENV')" | ${KUBECTL} delete -f - >> ${KUBE_INSTALL_LOG} 2>&1); then
                echo "🧹  delete elasticsearch cluster"
        else
                cat k8s/elasticsearch.yaml | envsubst "$(perl -e 'print "\$$_" for grep /^[_a-zA-Z]\w*$/, keys %ENV')" >> ${KUBE_INSTALL_LOG};
                echo -e "\e[33m⚠️   delete elasticsearch cluster\e[0m";
        fi;
fi;

unset ELASTIC_ADMIN_PASSWORD
unset ELASTIC_NODE

timeout=60;
ret=0 ;
until [ "$timeout" -le 0 -o "$ret" -eq "1" ] ; do
        ( ( ${KUBECTL} get pods -n ${KUBE_NAMESPACE} -l common.k8s.elastic.co/type=elasticsearch | grep -vq ${APP_GROUP}-es-default ) >> /dev/null 2>&1);
        ret=$? ;
        if [ "$ret" -ne "1" ] ; then printf "\r\033[2K%03d Wait for elasticsearch cluster to be terminated" $timeout ; fi ;
        ((timeout--)); sleep 1 ;
done ;
if [ "$timeout" == 0 ]; then
        (${KUBECTL} get pods -n ${KUBE_NAMESPACE} -l common.k8s.elastic.co/type=elasticsearch | grep -v NAME | awk '{print $1}' | xargs -I {} ${KUBECTL} -n ${KUBE_NAMESPACE} delete pod --force --grace-period=0 {}) >> ${KUBE_INSTALL_LOG} 2>&1;
fi
echo -en "\r\033[2K";

echo "${KUBE_NAMESPACE} status after deletions :" >> ${KUBE_INSTALL_LOG}

${KUBECTL} get all --namespace=${KUBE_NAMESPACE} >> ${KUBE_INSTALL_LOG}

echo "---------------------------------" >> ${KUBE_INSTALL_LOG}

echo "deploy_k8s_services" >> ${KUBE_INSTALL_LOG}

./scripts/deploy_k8s_services.sh
