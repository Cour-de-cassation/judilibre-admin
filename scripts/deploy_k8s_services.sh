#!/bin/bash

sudo echo -n

if [ ! -z "${ENV_FILE}" ];then
    export $(cat ${TARGET} | sed 's/#.*//g' | xargs);
fi;

if [ ! -z "${ENV_VARS}" ];then
    export ${ENV_VARS};
fi;

#install bins if needed
./scripts/check_install.sh

#log file
if [ -z "${KUBE_INSTALL_LOG}" ];then
        export KUBE_INSTALL_LOG=$(pwd)/k8s-$(date +%Y%m%d_%H%M).log;
fi

#set version from package & git / could be git tag instead
if [ -z "${VERSION}" ];then\
        export VERSION=$(./scripts/version.sh)
fi

export DOCKER_IMAGE=${DOCKER_USERNAME}/${APP_ID}:${VERSION}

if [ -z "${IP_WHITELIST}" ];then
        export IP_WHITELIST="0.0.0.0/0"
fi

if [ -z "${APP_ENV_SPEC}" ];then
        export APP_ENV_SPEC=" "
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

if [ -z "${ELASTIC_VERSION}" ];then
        export ELASTIC_VERSION=7.16.2;
fi;

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
                        export KUBECTL=$(which kubectl);
                else
                        export KUBECTL=$(pwd)/kubectl;
                        curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" > ${KUBECTL}
                        chmod +x ${KUBECTL};
                fi;
        fi;
fi;

#set up services to start
if [ -z "${APP_RESERVED_IP}" ];then
        export APP_RESERVED_IP_SPEC="#loadBalancerIP: None"
else
        export APP_RESERVED_IP_SPEC="loadBalancerIP: ${APP_RESERVED_IP}"
        echo "✓   IP ${APP_RESERVED_IP} will be affected to ${APP_ID} loadbalancer";
fi

if [ -z "${APP_HOST_ALTER}" ];then
        export TLS_ALTER_SPEC="#";
        export HOST_ALTER_SPEC="#";
        export CERT_ALTER_SPEC="#";
else
        export TLS_ALTER_SPEC=$(cat <<-TLS_ALTER_SPEC
- hosts:
    - ${APP_HOST_ALTER}
    secretName: ${APP_ID}-alter-cert-${ACME}
TLS_ALTER_SPEC
);
        export HOST_ALTER_SPEC=$(cat <<-HOST_ALTER_SPEC
- host: ${APP_HOST_ALTER}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${APP_ID}-svc
            port:
              number: 80
HOST_ALTER_SPEC
);
        export CERT_ALTER_SPEC=$(cat <<-CERT_ALTER_SPEC
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${APP_ID}-alter-cert-${ACME}
  namespace: ${KUBE_NAMESPACE}
spec:
  commonName: ${APP_HOST_ALTER}
  secretName: ${APP_ID}-alter-cert-${ACME}
  dnsNames:
    - ${APP_HOST_ALTER}
  issuerRef:
    name: letsencrypt-${ACME}
    kind: Issuer
CERT_ALTER_SPEC
);
fi

if [ -z "${KUBE_SERVICES}" ];then
        export KUBE_SERVICES="service deployment"
        if [ "${APP_GROUP}" == "judilibre-prive" ]; then
		if [ "${KUBE_ZONE}" == "local" -o "${APP_ID}" == "judifiltre-backend" ]; then
                	export KUBE_SERVICES="mongodb ${KUBE_SERVICES}";
		fi;
        else
                export KUBE_SERVICES="elasticsearch-roles elasticsearch-users elasticsearch ${KUBE_SERVICES}";
        fi;
fi

if [ "${APP_GROUP}" == "judilibre-prive" ];then
        if [ -z "${MONGODB_PASSWORD}" ]; then
                export MONGODB_PASSWORD=$(openssl rand -hex 32)
        fi
        if [ "${APP_ID}" == "label-backend" ]; then
                if [ -z "${MONGODB_NAME}" ]; then
                        export MONGODB_NAME=admin
                fi
                if [ -z "${MONGODB_HOST}" ]; then
                        export MONGODB_URI=mongodb://user:${MONGODB_PASSWORD}@mongodb-0.mongodb-svc.${KUBE_NAMESPACE}.svc.cluster.local
                fi
                if [ -z "${MONGODB_PORT}" ]; then
                        export MONGODB_PORT=27017
                fi
        fi
        if [ "${APP_ID}" == "judifiltre-backend" ]; then
                if [ -z "${JURICA_DBNAME}" ]; then
                        export JURICA_DBNAME=jurica
                fi
                if [ -z "${JURICA_URL}" ]; then
                        export JURICA_URL=mongodb://user:${MONGODB_PASSWORD}@mongodb-0.mongodb-svc.${KUBE_NAMESPACE}.svc.cluster.local:27017
                fi
                if [ -z "${JURINET_DBNAME}" ]; then
                        export JURINET_DBNAME=jurinet
                fi
                if [ -z "${JURINET_URL}" ]; then
                        export JURINET_URL=mongodb://user:${MONGODB_PASSWORD}@mongodb-0.mongodb-svc.${KUBE_NAMESPACE}.svc.cluster.local:27017
                fi
                if [ -z "${JUDIFILTRE_DBNAME}" ]; then
                        export JUDIFILTRE_DBNAME=judifiltredb
                fi
                if [ -z "${JUDIFILTRE_URL}" ]; then
                        export JUDIFILTRE_URL=mongodb://user:${MONGODB_PASSWORD}@mongodb-0.mongodb-svc.${KUBE_NAMESPACE}.svc.cluster.local:27017
                fi
        fi
        if [ "${APP_ID}" == "judilibre-index" ]; then
                if [ -z "${INTERNAL_DB_URI}" ]; then
                        export INTERNAL_DB_URI=mongodb://user:${MONGODB_PASSWORD}@mongodb-0.mongodb-svc.${KUBE_NAMESPACE}.svc.cluster.local:27017
                fi
                if [ -z "${EXTERNAL_DB_URI}" ]; then
                        export EXTERNAL_DB_URI=mongodb://user:${MONGODB_PASSWORD}@mongodb-0.mongodb-svc.${KUBE_NAMESPACE}.svc.cluster.local:27017
                fi
                if [ -z "${INTERNAL_DB_NAME}" ]; then
                        export INTERNAL_DB_NAME=internal
                fi
                if [ -z "${EXTERNAL_DB_NAME}" ]; then
                        export EXTERNAL_DB_NAME=external
                fi
        elif [ "${APP_ID}" == "judilibre-attachments" ]; then
                if [ -z "${MONGO_URI}" ]; then
                        export MONGO_URI=mongodb://user:${MONGODB_PASSWORD}@mongodb-0.mongodb-svc.${KUBE_NAMESPACE}.svc.cluster.local:27017
                fi
                if [ -z "${MONGO_DECISIONS_URI}" ]; then
                        export MONGO_DECISIONS_URI=mongodb://user:${MONGODB_PASSWORD}@mongodb-0.mongodb-svc.${KUBE_NAMESPACE}.svc.cluster.local:27017
                fi
                if [ -z "${MONGO_DBNAME}" ]; then
                        export MONGO_DBNAME=internal
                fi
                if [ -z "${MONGO_DECISIONS_DBNAME}" ]; then
                        export MONGO_DECISIONS_DBNAME=external
                fi
                if [ -z "${JWT_SECRET}" ]; then
                        export JWT_SECRET=$(openssl rand -hex 32)
                fi
                if [ -z "${COOKIE_SECRET}" ]; then
                        export COOKIE_SECRET=$(openssl rand -hex 32)
                fi;
        fi;
fi


if [ "${KUBE_ZONE}" == "local" ]; then
        #register host if not already done
        if ! (grep -q ${APP_HOST} /etc/hosts); then
                (echo $(grep "127.0.0.1" /etc/hosts) ${APP_HOST} | sudo tee -a /etc/hosts > /dev/null 2>&1);
        fi;
        #assume local kube conf (minikube or k3s)
        if [ "${APP_GROUP}" == "judilibre-prive" ];then
                if [[ "${APP_ID}" == "judilibre-"* ]]; then
                        export KUBE_SERVICES="${KUBE_SERVICES} ingress-local-secure";
                else
                        export KUBE_SERVICES="${KUBE_SERVICES} ingress-local";
                fi;
        else
                export KUBE_SERVICES="${KUBE_SERVICES} ingress-local";
        fi;
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
                fi;
                if [ "${K8S}" = "minikube" ]; then
                        minikube start;
                        if ! (minikube image list | grep -q ${DOCKER_IMAGE}); then
                                ./scripts/docker-build.sh;
                                (minikube image load ${DOCKER_IMAGE} >> ${KUBE_INSTALL_LOG} 2>&1);
                                echo -e "⤵️   Docker image imported to minikube";
                        fi;
                fi;
        fi;
        if [ "${KUBE_TYPE}" == "k3s" ]; then
                if (
                        (
                        ${KUBECTL} apply -f https://raw.githubusercontent.com/sleighzy/k3s-traefik-v2-kubernetes-crd/master/001-crd.yaml
                        ) > ${KUBE_INSTALL_LOG} 2>&1
                        ); then
                        echo "🚀  traefik crd";
                else
                        echo -e "\e[31m❌  traefik crd\e[0m" && exit 1;
                fi;
                if ! (sudo k3s ctr images check | grep -q ${DOCKER_IMAGE}); then
                        ./scripts/docker-check.sh || ./scripts/docker-build.sh || exit 1;
                        docker save ${DOCKER_IMAGE} --output /tmp/img.tar;
                        (sudo k3s ctr image import /tmp/img.tar >> ${KUBE_INSTALL_LOG} 2>&1);
                        echo -e "⤵️   Docker image imported to k3s";
                        rm /tmp/img.tar;
                fi;
        fi
else
        if [ "${KUBE_TYPE}" == "k3s" ];then
                if [[ ${APP_ID} == "judilibre-"* ]]; then
                        export KUBE_SERVICES="${KUBE_SERVICES} ingress-local-secure";
                else
                        export KUBE_SERVICES="${KUBE_SERVICES} ingress-local";
                fi
        elif [[ "${KUBE_ZONE}" == "scw"* ]]; then
                if [ -z "${KUBE_INGRESS}" ]; then
                        export KUBE_INGRESS=nginx
                fi;
                if [ "${KUBE_INGRESS}" == "nginx" ]; then
                        export KUBE_SOLVER=nginx;
                        export KUBE_CONF_ROUTE=ingress;
                        export KUBE_CONF_LB=loadbalancer;
                else
                        export KUBE_INGRESS=traefik;
                        export KUBE_SOLVER=traefik-cert-manager;
                        export KUBE_CONF_ROUTE=ingressroute;
                        export KUBE_CONF_LB=loadbalancer-traefik;
                fi;
                export KUBE_SERVICES="logging ${KUBE_CONF_LB} ${KUBE_SERVICES} $([ "${APP_GROUP}" != "monitor" ] && echo snapshots) issuer certificate ${KUBE_CONF_ROUTE}";
                if [ -z "${ACME}" ]; then
                        #define acme-staging for test purpose like dev env (weaker certificates, larger rate limits)
                        export ACME=acme;
                fi;
                if (${KUBECTL} get namespaces --namespace=cert-manager | grep -v 'No resources' | grep -q cert-manager); then
                        echo "✓   cert-manager";
                else
                        if (${KUBECTL} apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.yaml >> ${KUBE_INSTALL_LOG} 2>&1); then
                                echo "🚀  cert-manager";
                        else
                                echo -e "\e[31m❌  cert-manager\e[0m" && exit 1;
                        fi;
                fi;
        elif [ "${KUBE_TYPE}" == "openshift" ]; then
                export KUBE_SERVICES="${KUBE_SERVICES} ingressroute";
        fi;
fi;



#create namespace first
RESOURCENAME=$(envsubst < k8s/namespace.yaml | grep -e '^  name:' | sed 's/.*:\s*//;s/\s*//' | head -1);
if [ "${KUBE_TYPE}" == "openshift" ]; then
        if (${KUBECTL} get namespace ${KUBE_NAMESPACE} >> ${KUBE_INSTALL_LOG} 2>&1); then

		echo "✓   namespace ${KUBE_NAMESPACE}";
        else
                if (${KUBECTL} new-project ${KUBE_NAMESPACE} >> ${KUBE_INSTALL_LOG} 2>&1); then
                        echo "🚀  namespace ${KUBE_NAMESPACE}";
                else
                        echo -e "\e[31m❌  namespace ${KUBE_NAMESPACE}" && exit 1;
                fi;
        fi;
else
        if (${KUBECTL} get namespaces --namespace=${KUBE_NAMESPACE} | grep -v 'No resources' | grep -q ${KUBE_NAMESPACE}); then
                echo "✓   namespace ${KUBE_NAMESPACE}";
        else
                if (envsubst < k8s/namespace.yaml | ${KUBECTL} apply -f - >> ${KUBE_INSTALL_LOG} 2>&1); then
                        echo "🚀  namespace ${KUBE_NAMESPACE}";
                else
                        echo -e "\e[31m❌  namespace ${KUBE_NAMESPACE}" && exit 1;
                fi;
        fi;
fi;

#install elasticsearch kube cluster controller (in supervision and judilibre public envs)
if [ "${APP_GROUP}" == "monitor" -o "${APP_GROUP}" == "judilibre" ];then
        if (${KUBECTL} get elasticsearch >> ${KUBE_INSTALL_LOG} 2>&1); then
                echo "✓   elasticsearch k8s controller";
        else
                if ( (${KUBECTL} create -f https://download.elastic.co/downloads/eck/1.8.0/crds.yaml && ${KUBECTL} apply -f https://download.elastic.co/downloads/eck/1.8.0/operator.yaml) >> ${KUBE_INSTALL_LOG} 2>&1); then
                        echo "🚀  elasticsearch k8s controller";
                else
                        echo -e "\e[31m❌  elasticsearch k8s controller install failed" && exit 1;
                fi;
        fi;
fi;

## install mongodb kube cluster controller (in judilibre prive / local mode for CI)
if [ "${APP_GROUP}" == "judilibre-prive" -a "${KUBE_ZONE}" == "local" -o "${APP_ID}" == "judifiltre-backend" ]; then
        if (${KUBECTL} get namespace --namespace=${KUBE_NAMESPACE} | grep -v 'No resources' | grep -q 'mongodb' >> ${KUBE_INSTALL_LOG} 2>&1); then
                echo "✓   mongodb k8s controller";
        else
                if (
                        (
                                ${KUBECTL} apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/crd/bases/mongodbcommunity.mongodb.com_mongodbcommunity.yaml \
                                && ${KUBECTL} apply -n ${KUBE_NAMESPACE} -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role_binding.yaml \
                                && ${KUBECTL} apply -n ${KUBE_NAMESPACE} -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/service_account.yaml \
                                && ${KUBECTL} apply -n ${KUBE_NAMESPACE} -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role_binding_database.yaml \
                                && ${KUBECTL} apply -n ${KUBE_NAMESPACE} -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/service_account_database.yaml \
                                && ${KUBECTL} apply -n ${KUBE_NAMESPACE} -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role.yaml \
                                && ${KUBECTL} apply -n ${KUBE_NAMESPACE} -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role_database.yaml \
                                && ${KUBECTL} apply -n ${KUBE_NAMESPACE} -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/manager/manager.yaml
                        ) >> ${KUBE_INSTALL_LOG} 2>&1
                ); then
                        echo "🚀  mongodb k8s controller";
                else
                        echo -e "\e[31m❌  mongodb k8s controller\e[0m" && exit 1;
                fi
        fi
fi





#create configMap for elasticsearch stopwords
: ${STOPWORDS:=./elastic/config/analysis/stopwords_judilibre.txt}
if [ "${APP_GROUP}" == "judilibre" ];then
        RESOURCENAME=${APP_GROUP}-stopwords
        if (${KUBECTL} get configmap --namespace=${KUBE_NAMESPACE} 2>&1 | grep -v 'No resources' | grep -q ${RESOURCENAME}); then
                echo "✓   configmap ${APP_GROUP}/${RESOURCENAME}";
        else
                if [ -f "$STOPWORDS" ]; then
                        if (${KUBECTL} create configmap --namespace=${KUBE_NAMESPACE} ${RESOURCENAME} --from-file=${STOPWORDS} >> ${KUBE_INSTALL_LOG} 2>&1); then
                                echo "🚀  configmap ${APP_GROUP}/${RESOURCENAME}";
                        else
                                echo -e "\e[31m❌  configmap ${APP_GROUP}/${RESOURCENAME} !\e[0m" && exit 1;
                        fi;
                fi;
        fi;
fi;

#create common services (tls chain based on traefik hypothesis, web exposed k8s like Scaleway, ovh ...)
: ${ELASTIC_SEARCH_PASSWORD:=changeme}
export ELASTIC_SEARCH_HASH=$(htpasswd -bnBC 10 "" ${ELASTIC_SEARCH_PASSWORD} | tr -d ':\n' | sed 's/\$2y/\$2a/')


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

timeout=${START_TIMEOUT};
for resource in ${KUBE_SERVICES}; do
        if [ -f "k8s/${resource}-${KUBE_TYPE}.yaml" ]; then
                RESOURCEFILE=k8s/${resource}-${KUBE_TYPE}.yaml
        elif [ -f "k8s/${resource}-${KUBE_TYPE}-${APP_ID}.yaml" ]; then
                RESOURCEFILE=k8s/${resource}-${KUBE_TYPE}-${APP_ID}.yaml
        elif [ -f "k8s/${resource}-${APP_ID}.yaml" ]; then
                RESOURCEFILE=k8s/${resource}-${APP_ID}.yaml;
        elif [ -f "k8s/${resource}.yaml" ]; then
                RESOURCEFILE=k8s/${resource}.yaml;
        else
                echo -e "\e[31m❌  ${resource} has no config file like k8s/${resource}(-${KUBE_TYPE})?(-${APP-ID})?\e[0m" && exit 1;
        fi
        NAMESPACE=$(envsubst < ${RESOURCEFILE} | grep -e '^  namespace:' | sed 's/.*:\s*//;s/\s*//;' | head -1);
        RESOURCENAME=$(envsubst < ${RESOURCEFILE} | grep -e '^  name:' | sed 's/.*:\s*//;s/\s*//' | head -1);
        RESOURCETYPE=$(envsubst < ${RESOURCEFILE} | grep -e '^kind:' | sed 's/.*:\s*//;s/\s*//' | head -1);
        if [ ${resource} == "elasticsearch" ];then
                NAMESPACE=${KUBE_NAMESPACE};
                RESOURCENAME=${APP_GROUP};
                RESOURCETYPE=Elasticsearch;
        fi;
        if [ -f "scripts/pre-${resource}.sh" ];then
                ./scripts/pre-${resource}.sh
        fi
        if [ "${resource}" == "deployment" ]; then
                # elastic secrets
                if (${KUBECTL} get secret --namespace=${KUBE_NAMESPACE} ${APP_ID}-es-path-with-auth >> ${KUBE_INSTALL_LOG} 2>&1); then
                        echo "✓   secret ${NAMESPACE}/${APP_ID}-es-path-with-auth";
                else
                        if [ "${APP_ID}" == "judilibre-admin" ]; then
                                if (${KUBECTL} create secret --namespace=${KUBE_NAMESPACE} generic ${APP_ID}-es-path-with-auth --from-literal="elastic-node=https://elastic:${ELASTIC_ADMIN_PASSWORD}@${APP_GROUP}-es-http:9200" >> ${KUBE_INSTALL_LOG} 2>&1); then
                                        echo "🚀  secret ${NAMESPACE}/${APP_ID}-es-path-with-auth";
                                else
                                        echo -e "\e[31m❌  secret ${NAMESPACE}/${APP_ID}-es-path-with-auth !\e[0m" && exit 1;
                                fi;
                        elif [ "${APP_GROUP}" != "judilibre-prive" ]; then
                                if (${KUBECTL} create secret --namespace=${KUBE_NAMESPACE} generic ${APP_ID}-es-path-with-auth --from-literal="elastic-node=https://search:${ELASTIC_SEARCH_PASSWORD}@${APP_GROUP}-es-http:9200" >> ${KUBE_INSTALL_LOG} 2>&1);then
                                        echo "🚀  secret ${NAMESPACE}/${APP_ID}-es-path-with-auth";
                                else
                                        echo -e "\e[31m❌  secret ${NAMESPACE}/${APP_ID}-es-path-with-auth !\e[0m" && exit 1;
                                fi;
                        else # judilibre-prive
				if [[ "${APP_ID}" == "judilibre-"* ]]; then
                                        ./scripts/generate-certificate.sh;
                                        if (${KUBECTL} get secret --namespace=${NAMESPACE} deployment-cert >> ${KUBE_INSTALL_LOG} 2>&1); then
                                                echo "✓   secret ${NAMESPACE}/deployment-cert";
                                        else
                                                if (${KUBECTL} create secret --namespace=${NAMESPACE} generic deployment-cert --from-file=server.crt --from-file=server.key >> ${KUBE_INSTALL_LOG} 2>&1); then
                                                        echo "🚀  secret ${NAMESPACE}/deployment-cert";
                                                else
                                                        echo -e "\e[31m❌  secret ${NAMESPACE}/deployment-cert\e[0m" && exit 1;
                                                fi
                                        fi;
                                        cp server.crt tls.crt >> ${KUBE_INSTALL_LOG} 2>&1
                                        if (${KUBECTL} get secret --namespace=${NAMESPACE} deployment-cert >> ${KUBE_INSTALL_LOG} 2>&1); then
                                                echo "✓   secret ${NAMESPACE}/deployment-cert-public";
                                        else
                                                if (${KUBECTL} create secret --namespace=${NAMESPACE} generic deployment-cert-public --from-file=tls.crt >> ${KUBE_INSTALL_LOG} 2>&1); then
                                                        echo "🚀  secret ${NAMESPACE}/deployment-cert-public";
                                                else
                                                        echo -e "\e[31m❌  secret ${NAMESPACE}/deployment-cert-public\e[0m" && exit 1;
                                                fi
                                        fi;
				fi;
                        fi;
                fi;
                # api secret / password is dummy for search API, only used in admin api
                if [ "${APP_GROUP}" != "judilibre-prive" ]; then
                        if [ -z "${HTTP_PASSWD}" -a "${APP_GROUP}" == "judilibre" ];then
                                export HTTP_PASSWD=$(openssl rand -hex 32)
                                echo "🔒️   generated default http-passwd for ${APP_ID} ${HTTP_PASSWD}";
                        fi
                        if (${KUBECTL} get secret --namespace=${KUBE_NAMESPACE} ${APP_ID}-http-passwd >> ${KUBE_INSTALL_LOG} 2>&1); then
                                echo "✓   secret ${NAMESPACE}/${APP_ID}-http-passwd";
                        else
                                if (${KUBECTL} create secret --namespace=${KUBE_NAMESPACE} generic ${APP_ID}-http-passwd --from-literal="http-passwd=${HTTP_PASSWD}" >> ${KUBE_INSTALL_LOG} 2>&1); then
                                        echo "🚀  secret ${NAMESPACE}/${APP_ID}-http-passwd";
                                else
                                        echo -e "\e[31m❌  secret ${NAMESPACE}/${APP_ID}-http-passwd !\e[0m" && exit 1;
                                fi;
                        fi;
                fi;
        fi;
        if [ "${ressource}" == "issuer" ]; then
                ret=1 ;
                until [ "$timeout" -le 0 -o "$ret" -eq "0" ] ; do
                        (${KUBECTL} get pods -n cert-manager -l app=cert-manager -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' | grep -q True);
                        ret=$? ;
                        if [ "$ret" -ne "0" ] ; then printf "\r\033[2K%03d Wait for cert-manager to be ready" $timeout ; fi ;
                        ((timeout--)); sleep 1 ;
                done ;
                echo -en "\r\033[2K";
        fi;
        if ( ! (echo ${KUBE_SERVICES_FORCE_UPDATE} | tr ' ' '\n' | grep -q ${resource}) ) && (${KUBECTL} get ${RESOURCETYPE} --namespace=${NAMESPACE} 2>&1 | grep -v 'No resources' | grep -q ${RESOURCENAME}); then
                echo "✓   ${resource} ${NAMESPACE}/${RESOURCENAME}";
        else
                if [ "${resource}" == "ingress" -a "${APP_GROUP}" != "monitor" ]; then
                        export IP_WHITELIST=$(./scripts/whitelist.sh)
                fi
                # don't substitute empty vars, allowing them to be receplaced within kube itself
                if (envsubst "$(perl -e 'print "\$$_" for grep /^[_a-zA-Z]\w*$/, keys %ENV')" < ${RESOURCEFILE} | ${KUBECTL} apply -f - >> ${KUBE_INSTALL_LOG} 2>&1); then
                        echo "🚀  ${resource} ${NAMESPACE}/${RESOURCENAME}";
                else
                        echo "${ressource} ${NAMESPACE}/${RESOURCENAME} conf attemp was:" >> ${KUBE_INSTALL_LOG} 2>&1
                        (envsubst "$(perl -e 'print "\$$_" for grep /^[_a-zA-Z]\w*$/, keys %ENV')" < ${RESOURCEFILE}) >> ${KUBE_INSTALL_LOG} 2>&1
                        echo -e "\e[31m❌  ${resource} ${NAMESPACE}/${RESOURCENAME} !\e[0m" && exit 1;
                fi;
        fi;
        if [ "${RESOURCETYPE}" == "Elasticsearch" ]; then
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
        if [ "${resource}" == "loadbalancer" ]; then
                ret=0;ok="";
                if [ "${KUBE_TYPE}" != "openshift" ]; then
                        fails=0
                        until [ "$timeout" -le 0 -o ! -z "$ok" ] ; do
                                lb=$(${KUBECTL} get service --namespace=kube-system | grep -i loadbalancer | grep -v pending | egrep "${APP_ID}|traefik" | awk '{print $1}');
                                if [ ! -z "$lb" ]; then
                                        ret=$(${KUBECTL} describe service/${lb} --namespace=kube-system | grep Endpoints | awk 'BEGIN{s=0}($2){s++}END{printf s}');
                                fi;
                                if [ "$ret" -eq "0" ] ; then
                                        printf "\r\033[2K%03d Wait for Loadbalancer to be ready" $timeout;
                                else
                                        if [ ! -z "${SCW_DNS_SECRET_TOKEN}" -a -z "${APP_RESERVED_IP}" -a -z "${SCW_DNS_UPDATE_IP}" ];then
                                                export SCW_DNS_UPDATE_IP=$(${KUBECTL} get service --namespace=kube-system | grep -i loadbalancer | grep -v pending | egrep "${APP_ID}|traefik" | awk '{print $4}');
                                                if [ -z "${SCW_DNS_UPDATE_IP}" ];then
                                                        echo -e "\r\033[2K\e[31m❌  loadblancer failed to get public IP" && exit 1;
                                                fi
                                                echo -e "\r\033[2K✓   loadbalancer got public IP ${SCW_DNS_UPDATE_IP}";
                                                ./scripts/update_dns.sh
                                        fi;
                                        if (curl -s -o /dev/null -k --max-time 1 -XGET ${APP_SCHEME}://${APP_HOST}:${APP_PORT}); then
                                                ok="ok";
                                        else
                                                ((fails++))
                                                printf "\r\033[2K%03d Wait for Endpoints to be ready" $timeout;
                                                if [ $fails -gt 30 -a -z "${APP_RESERVED_IP}" ];then
                                                        # avoid DNS ttl latency
                                                        ./scripts/update_dns_local.sh
                                                        fails=0
                                                fi;
                                        fi;
                                fi;
                                ((timeout--)); sleep 1 ;
                        done ;
                        if [ -z "$ok" ];then
                                echo -en "\r\033[2K\e[31m❌  loadbalancer is not ready !\e[0m\n" && (${KUBECTL} get service --namespace=kube-system | grep -i loadbalancer) && exit 1
                        else
                                (echo -en "\r\033[2K✓   loadbalancer is ready\n")
                        fi;
                fi;
        fi;
        if [ -f "scripts/post-${resource}.sh" ];then
                ./scripts/post-${resource}.sh
        fi
done;

export START_TIMEOUT=$timeout

./scripts/wait_services_readiness.sh || exit 1;

# elasticsearch init
: ${ELASTIC_TEMPLATE:=./elastic/template.json}

export ELASTIC_NODE="https://elastic:${ELASTIC_ADMIN_PASSWORD}@localhost:9200"

if [ -f "${ELASTIC_TEMPLATE}" -a "${APP_GROUP}" == "judilibre" ];then
        if ! (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k "${ELASTIC_NODE}/_template/t_judilibre" 2>&1 | grep -q ${APP_GROUP}); then
                if (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k -XPUT "${ELASTIC_NODE}/_template/t_judilibre" -H 'Content-Type: application/json' -d "$(cat ${ELASTIC_TEMPLATE})" >> ${KUBE_INSTALL_LOG} 2>&1); then
                        echo "🚀  elasticsearch templates";
                else
                        echo -e "\e[31m❌  elasticsearch templates !\e[0m" && exit 1;
                fi;
        else
                echo "✓   elasticsearch templates";
        fi;
fi;

: ${SCW_REGION:="fr-par"}
if [ ! -z "${SCW_DATA_SECRET_KEY}" ];then
        export RCLONE_CONFIG_S3_TYPE=s3
        export RCLONE_CONFIG_S3_ACCESS_KEY_ID=${SCW_DATA_ACCESS_KEY}
        export RCLONE_CONFIG_S3_SECRET_ACCESS_KEY=${SCW_DATA_SECRET_KEY}
        export RCLONE_CONFIG_S3_ENV_AUTH=false
        export RCLONE_CONFIG_S3_ENDPOINT=s3.${SCW_REGION}.scw.cloud
        export RCLONE_CONFIG_S3_REGION=${SCW_REGION}
        export RCLONE_CONFIG_S3_SERVER_SIDE_ENCRYPTION=
        export RCLONE_CONFIG_S3_FORCE_PATH_STYLE=false
        export RCLONE_CONFIG_S3_LOCATION_CONSTRAINT=
        export RCLONE_CONFIG_S3_STORAGE_CLASS=
        export RCLONE_CONFIG_S3_ACL=private
        if (rclone -q ls s3:${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}-${KUBE_NAMESPACE} >> ${KUBE_INSTALL_LOG} 2>&1);then
                echo "✓   elasticsearch s3 backup bucket";
        else
                if (rclone -q mkdir s3:${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}-${KUBE_NAMESPACE} >> ${KUBE_INSTALL_LOG} 2>&1);then
                        echo "🚀  elasticsearch s3 backup bucket";
                else
                        echo -e "\e[31m❌  elasticsearch s3 backup bucket !\e[0m" && exit 1;
                fi;
        fi
        ELASTIC_REPOSITORY="{
                'type': 's3',
                'settings': {
                        'bucket': '${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}-${KUBE_NAMESPACE}',
                        'region': '${SCW_REGION}',
                        'endpoint': 's3.${SCW_REGION}.scw.cloud'
                }
        }"
        ELASTIC_REPOSITORY=$(echo ${ELASTIC_REPOSITORY} | tr "'" '"' | jq -c '.')

        if ! (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s --fail -k "${ELASTIC_NODE}/_snapshot/${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}-${KUBE_NAMESPACE}" >> ${KUBE_INSTALL_LOG} 2>&1); then
                if (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k -XPUT "${ELASTIC_NODE}/_snapshot/${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}-${KUBE_NAMESPACE}" -H 'Content-Type: application/json' -d "${ELASTIC_REPOSITORY}" >> ${KUBE_INSTALL_LOG} 2>&1); then
                        echo "🚀  elasticsearch set backup repository";
                        ELASTIC_SNAPSHOT=$(${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s --fail -k "${ELASTIC_NODE}/_cat/snapshots/${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}-${KUBE_NAMESPACE}" 2>&1 | grep SUCCESS | tail -1 | awk '{print $1}')
                        if [ ! -z "${ELASTIC_SNAPSHOT}" ];then
                                if (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s --fail -k -XPOST "${ELASTIC_NODE}/_snapshot/${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}-${KUBE_NAMESPACE}/${ELASTIC_SNAPSHOT}/_restore" -H 'Content-Type: application/json' -d '{"indices":"'${ELASTIC_INDEX}'"}' >> ${KUBE_INSTALL_LOG} 2>&1);then
                                        echo "🔄  elasticsearch backup ${ELASTIC_SNAPSHOT} restored";
                                else
                                        echo -e "\e[33m⚠️   elasticsearch backup ${ELASTIC_SNAPSHOT} not restored\e[0m";
                                fi;
                        else
                                ${KUBECTL} --namespace=${KUBE_NAMESPACE} get all
                                ${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s --fail -k "${ELASTIC_NODE}/_cat/snapshots/${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}-${KUBE_NAMESPACE}"
                                echo -e "\e[33m⚠️   found no elasticsearch backup to restore\e[0m";
                        fi;
                else
                        echo -e "\e[31m❌  elasticsearch set backup repository !\e[0m" && exit 1;
                fi;
        else
                echo "✓   elasticsearch set backup repository";
        fi;
fi;
if [ "${APP_GROUP}" == "judilibre" ];then
        if ! (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k "${ELASTIC_NODE}/_cat/indices" 2>&1 | grep -q ${ELASTIC_INDEX}); then
                if (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k -XPUT "${ELASTIC_NODE}/${ELASTIC_INDEX}" >> ${KUBE_INSTALL_LOG} 2>&1); then
                        echo "🚀  elasticsearch default index";
                else
                        echo -e "\e[31m❌  elasticsearch default index !\e[0m" && exit 1;
                fi;
        else
                echo "✓   elasticsearch default index";
        fi;
fi;
