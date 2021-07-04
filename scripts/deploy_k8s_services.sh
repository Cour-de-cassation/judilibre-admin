#!/bin/bash

#install bins if needed
./scripts/check_install.sh

#set version from package & git / could be git tag instead
if [ -z "${VERSION}" ];then\
        export VERSION="$(cat package.json | jq -r '.version')-$(git rev-parse --short HEAD)"
fi

export DOCKER_IMAGE=${DOCKER_USERNAME}/${APP_ID}:${VERSION}

if [ -z "${KUBECTL}" ]; then
        if [ "${KUBE_TYPE}" == "openshift" ]; then
                if (which oc > /dev/null); then
                        export KUBECTL=$(which oc);
                else
                        export KUBECTL=$(pwd)/oc;
                        curl -s https://downloads-openshift-console.apps.opj-prd.tdp.ovh/amd64/linux/oc.tar -o - | tar xf -
                fi;
        else
                if (which kubectl > /dev/null); then
                        export export KUBECTL=$(which kubectl);
                else
                        export KUBECTL=$(pwd)/kubectl;
                        curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" > ${KUBECTL}
                        chmod +x ${KUBECTL};
                fi;
        fi;
fi;

#set up services to start
if [ -z ${KUBE_SERVICES} ];then
        export KUBE_SERVICES="elasticsearch-roles elasticsearch-users elasticsearch service deployment";
fi;
if [ "${KUBE_ZONE}" == "local" ]; then
        #register host if not already done
        if ! (grep -q ${APP_HOST} /etc/hosts); then
                (echo $(grep "127.0.0.1" /etc/hosts) ${APP_HOST} | sudo tee -a /etc/hosts > /dev/null 2>&1);
        fi;
        #assume local kube conf (minikube or k3s)
        export KUBE_SERVICES="${KUBE_SERVICES} ingress-local";
        if ! (${KUBECTL} version 2>&1 | grep -q Server); then
                if [ -z "${KUBE_TYPE}" ]; then
                        # prefer k3s for velocity of install and startup in CI
                        export K8S=k3s;
                fi;
                if [ "${KUBE_TYPE}" == "k3s" ]; then
                        if ! (which k3s > /dev/null 2>&1); then
                                (curl -sfL https://get.k3s.io | sh - 2>&1 |\
                                        awk 'BEGIN{s=0}{printf "\r☸️  Installing k3s (" s++ "/16)"}') && echo -e "\r\033[2K☸️   Installed k3s";
                        fi;
                        mkdir -p ~/.kube;
                        export KUBECONFIG=${HOME}/.kube/config-local-k3s.yaml;
                        sudo cp /etc/rancher/k3s/k3s.yaml ${KUBECONFIG};
                        sudo chown ${USER} ${KUBECONFIG};
                        if ! (sudo k3s ctr images check | grep -q ${DOCKER_IMAGE}); then
                                ./scripts/docker-build.sh;
                                docker save ${DOCKER_IMAGE} --output /tmp/img.tar;
                                (sudo k3s ctr image import /tmp/img.tar > /dev/null 2>&1);
                                echo -e "⤵️   Docker image imported to k3s";
                                rm /tmp/img.tar;
                        fi;
                fi;
                if [ "${K8S}" = "minikube" ]; then
                        minikube start;
                        if ! (minikube image list | grep -q ${DOCKER_IMAGE}); then
                                ./scripts/docker-build.sh;
                                (minikube image load ${DOCKER_IMAGE} > /dev/null 2>&1);
                                echo -e "⤵️   Docker image imported to minikube";
                        fi;
                fi;
        fi;
else
        if [[ "${KUBE_ZONE}" == "scw"* ]]; then
                if [ -z "${KUBE_INGRESS}" ]; then
                        export KUBE_INGRESS=nginx
                        export KUBE_SOLVER=nginx;
                        export KUBE_CONF_ROUTE=ingress;
                        export KUBE_CONF_LB=loadbalancer;
                else
                        export KUBE_INGRESS=traefik;
                        export KUBE_SOLVER=traefik-cert-manager;
                        export KUBE_CONF_ROUTE=ingressroute;
                        export KUBE_CONF_LB=loadbalancer-traefik;
                fi;
                export KUBE_SERVICES="${KUBE_SERVICES} issuer certificate ${KUBE_CONF_ROUTE} ${KUBE_CONF_LB}";
                if [ -z "${ACME}" ]; then
                        #define acme-staging for test purpose like dev env (weaker certificates, larger rate limits)
                        export ACME=acme;
                fi;
                if (${KUBECTL} get namespaces --namespace=cert-manager | grep -v 'No resources' | grep -q cert-manager); then
                        echo "✓   cert-manager";
                else
                        if (${KUBECTL} apply -f https://github.com/jetstack/cert-manager/releases/download/v1.4.0/cert-manager.yaml 2>&1 > /dev/null); then
                                echo "🚀  cert-manager";
                        else
                                echo -e "\e[31m❌  cert-manager";
                        fi;
                fi;
        fi;
        if [ "${KUBE_TYPE}" == "openshift" ]; then
                export KUBE_SERVICES="${KUBE_SERVICES} ingressroute";
        fi;
fi;

#get current branch
if [ -z "${GIT_BRANCH}" ];then
        export GIT_BRANCH=$(git branch | grep '*' | awk '{print $2}');
fi;

#default k8s namespace
if [ -z "${KUBE_NAMESPACE}" ]; then
        export KUBE_NAMESPACE=${APP_GROUP}-${KUBE_ZONE}-$(echo ${GIT_BRANCH} | tr '/' '-')
fi;

#display env if DEBUG
if [ ! -z "${APP_DEBUG}" ]; then
        env | egrep '^(VERSION|KUBE|DOCKER_IMAGE|GIT_TOKEN|APP_|ELASTIC_)' | sort
fi;

#create namespace first
RESOURCENAME=$(envsubst < k8s/namespace.yaml | grep -e '^  name:' | sed 's/.*:\s*//;s/\s*//');
if [ "${KUBE_TYPE}" == "openshift" ]; then
        if (${KUBECTL} get namespace ${KUBE_NAMESPACE} > /dev/null 2>&1); then

		echo "✓   namespace ${KUBE_NAMESPACE}";
        else
                if (${KUBECTL} new-project ${KUBE_NAMESPACE} > /dev/null 2>&1); then
                        echo "🚀  namespace ${KUBE_NAMESPACE}";
                else
                        echo -e "\e[31m❌  namespace ${KUBE_NAMESPACE}" && exit 1;
                fi;
        fi;
else
        if (${KUBECTL} get namespaces --namespace=${KUBE_NAMESPACE} | grep -v 'No resources' | grep -q ${KUBE_NAMESPACE}); then
                echo "✓   namespace ${KUBE_NAMESPACE}";
        else
                if (envsubst < k8s/namespace.yaml | ${KUBECTL} apply -f - > /dev/null 2>&1); then
                        echo "🚀  namespace ${KUBE_NAMESPACE}";
                else
                        echo -e "\e[31m❌  namespace ${KUBE_NAMESPACE}" && exit 1;
                fi;
        fi;
fi;

#install elasticsearch kube cluster controller
if (${KUBECTL} get elasticsearch > /dev/null 2>&1); then
        echo "✓   elasticsearch k8s controller";
else
        if (${KUBECTL} apply -f https://download.elastic.co/downloads/eck/1.6.0/all-in-one.yaml > /dev/null 2>&1); then
                echo "🚀  elasticsearch k8s controller";
        else
                echo -e "\e[31m❌  elasticsearch k8s controller install failed" && exit 1;
        fi;
fi;

#create configMap for elasticsearch stopwords
: ${STOPWORDS:=./elastic/config/analysis/stopwords_judilibre.txt}
RESOURCENAME=${APP_GROUP}-stopwords
if (${KUBECTL} get configmap --namespace=${KUBE_NAMESPACE} 2>&1 | grep -v 'No resources' | grep -q ${RESOURCENAME}); then
        echo "✓   configmap ${APP_GROUP}/${RESOURCENAME}";
else
        if [ -f "$STOPWORDS" ]; then
                if (${KUBECTL} create configmap --namespace=${KUBE_NAMESPACE} ${RESOURCENAME} --from-file=${STOPWORDS} > /dev/null 2>&1); then
                        echo "🚀  configmap ${APP_GROUP}/${RESOURCENAME}";
                else
                        echo -e "\e[31m❌  configmap ${APP_GROUP}/${RESOURCENAME} !\e[0m" && exit 1;
                fi;
        fi;
fi;

#create common services (tls chain based on traefik hypothesis, web exposed k8s like Scaleway, ovh ...)
: ${ELASTIC_SEARCH_PASSWORD:=changeme}
export ELASTIC_SEARCH_HASH=$(htpasswd -bnBC 10 "" ${ELASTIC_SEARCH_PASSWORD} | tr -d ':\n' | sed 's/\$2y/\$2a/')

timeout=${START_TIMEOUT};
for resource in ${KUBE_SERVICES}; do
        if [ -f k8s/${resource}-${KUBE_TYPE}.yaml ]; then
                RESOURCEFILE=k8s/${resource}-${KUBE_TYPE}.yaml;
        else
                RESOURCEFILE=k8s/${resource}.yaml;
        fi;
        NAMESPACE=$(envsubst < ${RESOURCEFILE} | grep -e '^  namespace:' | sed 's/.*:\s*//;s/\s*//;');
        RESOURCENAME=$(envsubst < ${RESOURCEFILE} | grep -e '^  name:' | sed 's/.*:\s*//;s/\s*//');
        RESOURCETYPE=$(envsubst < ${RESOURCEFILE} | grep -e '^kind:' | sed 's/.*:\s*//;s/\s*//');
        if [ "${resource}" == "deployment" ]; then
                # elastic secrets
                if (${KUBECTL} get secret --namespace=${KUBE_NAMESPACE} ${APP_ID}-es-path-with-auth > /dev/null 2>&1); then
                        echo "✓   secret ${NAMESPACE}/${APP_ID}-es-path-with-auth";
                else
                        if [[ "${APP_ID}" == *"admin" ]]; then
                                if (${KUBECTL} create secret --namespace=${KUBE_NAMESPACE} generic ${APP_ID}-es-path-with-auth --from-literal="elastic-node=https://elastic:${ELASTIC_ADMIN_PASSWORD}@${APP_GROUP}-es-http:9200" > /dev/null 2>&1); then
                                        echo "🚀  secret ${NAMESPACE}/${APP_ID}-es-path-with-auth";
                                else
                                        echo -e "\e[31m❌  secret ${NAMESPACE}/${APP_ID}-es-path-with-auth !\e[0m" && exit 1;
                                fi;
                        else
                                if (${KUBECTL} create secret --namespace=${KUBE_NAMESPACE} generic ${APP_ID}-es-path-with-auth --from-literal="elastic-node=https://search:${ELASTIC_SEARCH_PASSWORD}@${APP_GROUP}-es-http:9200" > /dev/null 2>&1);then
                                        echo "🚀  secret ${NAMESPACE}/${APP_ID}-es-path-with-auth";
                                else
                                        echo -e "\e[31m❌  secret ${NAMESPACE}/${APP_ID}-es-path-with-auth !\e[0m" && exit 1;
                                fi;
                        fi;
                fi;
                # api secret / password is dummy for search API, only used in admin api
                if [ -z "${HTTP_PASSWD}" ];then
                        export HTTP_PASSWD=$(openssl rand -hex 32)
                        echo "🔒️   generated default http-passwd for ${APP_ID} ${HTTP_PASSWD}";
                fi
                if (${KUBECTL} get secret --namespace=${KUBE_NAMESPACE} ${APP_ID}-http-passwd > /dev/null 2>&1); then
                        echo "✓   secret ${NAMESPACE}/${APP_ID}-http-passwpasswdord";
                else
                        if (${KUBECTL} create secret --namespace=${KUBE_NAMESPACE} generic ${APP_ID}-http-passwd --from-literal="http-passwd=${HTTP_PASSWD}" > /dev/null 2>&1); then
                                echo "🚀  secret ${NAMESPACE}/${APP_ID}-http-passwd";
                        else
                                echo -e "\e[31m❌  secret ${NAMESPACE}/${APP_ID}-http-passwd !\e[0m" && exit 1;
                        fi;
                fi;
        fi;
        if (${KUBECTL} get ${RESOURCETYPE} --namespace=${NAMESPACE} 2>&1 | grep -v 'No resources' | grep -q ${RESOURCENAME}); then
                echo "✓   ${resource} ${NAMESPACE}/${RESOURCENAME}";
        else
                if (envsubst < ${RESOURCEFILE} | ${KUBECTL} apply -f - > /dev/null); then
                        echo "🚀  ${resource} ${NAMESPACE}/${RESOURCENAME}";
                else
                        echo -e "\e[31m❌  ${resource} ${NAMESPACE}/${RESOURCENAME} !\e[0m" && exit 1;
                fi;
        fi;
        if [ "${resource}" == "elasticsearch" ]; then
                ret=1 ;\
                until [ "$timeout" -le 0 -o "$ret" -eq "0" ] ; do
                        (${KUBECTL} get secret --namespace=${NAMESPACE} ${APP_GROUP}-es-elastic-user -o go-template='{{.data.elastic | base64decode}}' > /dev/null 2>&1);
                        ret=$? ;
                        if [ "$ret" -ne "0" ] ; then printf "\r\033[2K%03d Wait for elasticsearch to setup secret" $timeout ; fi ;
                        ((timeout--)); sleep 1 ;
                done ;
                echo -en "\r\033[2K";
                export ELASTIC_ADMIN_PASSWORD=$(${KUBECTL} get secret --namespace=${NAMESPACE} ${APP_GROUP}-es-elastic-user -o go-template='{{.data.elastic | base64decode}}');
        fi;
done;

export START_TIMEOUT=$timeout

./scripts/wait_services_readiness.sh || exit 1;

# elasticsearch init
: ${ELASTIC_TEMPLATE:=./elastic/template-medium.json}

export ELASTIC_NODE="https://elastic:${ELASTIC_ADMIN_PASSWORD}@localhost:9200"

if [ -f "${ELASTIC_TEMPLATE}" ];then
        if ! (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k "${ELASTIC_NODE}/_template/t_judilibre" 2>&1 | grep -q ${APP_GROUP}); then
                if (cat ${ELASTIC_TEMPLATE} | ${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k -XPUT "${ELASTIC_NODE}/_template/t_judilibre" -H 'Content-Type: application/json' -d "$(</dev/stdin)" > /dev/null 2>&1); then
                        echo "🚀   elasticsearch templates";
                else
                        echo -e "\e[31m❌  elasticsearch templates !\e[0m" && exit 1;
                fi;
        else
                echo "✓   elasticsearch templates";
        fi;
fi;
if ! (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k "${ELASTIC_NODE}/_cat/indices" 2>&1 | grep -q ${ELASTIC_INDEX}); then
        if (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k -XPUT "${ELASTIC_NODE}/${ELASTIC_INDEX}" > /dev/null 2>&1); then
                echo "🚀   elasticsearch default index";
        else
                echo -e "\e[31m❌  elasticsearch default index !\e[0m" && exit 1;
        fi;
else
        echo "✓   elasticsearch default index";
fi;
