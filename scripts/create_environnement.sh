#!/bin/bash

sudo echo -n

: ${SCW_REGION:="fr-par"}
: ${SCW_LB_IP_API:="https://api.scaleway.com/lb/v1/regions/${SCW_REGION}/ips"}

if [ -z "${ENV_FILES}" ];then
    echo -e "\e[31m❌  your must provide ENV_FILES to deploy targets" && exit 1;
fi

if [ ! -d judilibre-search ];then
    git clone https://github.com/Cour-de-cassation/judilibre-search;
fi;

for TARGET in $ENV_FILES;do
    export export $(cat ${TARGET} | sed 's/#.*//g' | xargs)

    ##############################
    # step 1. reserve IPs of LB and update DNS
    echo "▶️   reserve IPs and set DNS for ${TARGET}";
    #
    # IP of admin API
    export APP_HOST_ADMIN=${APP_HOST}
    export APP_RESERVED_IP=$(curl -s -X POST "${SCW_LB_IP_API}" -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" -H "Content-Type: application/json" \
-d "{\"project_id\":\"$SCW_KUBE_PROJECT_ID\"}" | jq -r .ip_address | grep -v null)
    if [ -z "${APP_RESERVED_IP}" ];then
        echo -e "\r\033[2K\e[31m❌  IP reservation failed for ${APP_ID} ![0m" && exit 1
    else
        echo "🚀   IP ${APP_RESERVED_IP} reserved for ${APP_ID}"
    fi;
    export SCW_DNS_UPDATE_IP=${APP_RESERVED_IP}
    ./scripts/update_dns.sh || exit 1;
    #
    # IP of search API
    export APP_RESERVED_IP_SEARCH=$(curl -s -X POST "${SCW_LB_IP_API}" -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" -H "Content-Type: application/json" \
-d "{\"project_id\":\"$SCW_KUBE_PROJECT_ID\"}" | jq -r .ip_address | grep -v null)
    if [ -z ${APP_RESERVED_IP_SEARCH} ];then
        echo -e "\r\033[2K\e[31m❌  IP reservation failed for ${APP_ID_SEARCH} ![0m" && exit 1
    else
        echo "🚀  IP ${APP_RESERVED_IP_SEARCH} reserved for ${APP_ID_SEARCH}"
    fi;
    export APP_HOST=${APP_HOST_SEARCH}
    export SCW_DNS_UPDATE_IP=${APP_RESERVED_IP_SEARCH}
    ./scripts/update_dns.sh || exit 1;
    #
    unset SCW_DNS_UPDATE_IP
    export APP_HOST=${APP_HOST_ADMIN}

    ################################
    # step 2. create cluster
    echo "▶️   create cluster for ${TARGET}";
    ./scripts/create_k8s_cluster.sh || exit 1

    ################################
    # k8s deployment
    #
    # admin API
    echo "▶️   k8s deployment of ${APP_ID} to ${TARGET}";
    (./scripts/deploy_k8s_services.sh) || exit 1;
    #
    # search API
    export APP_ID=${APP_ID_SEARCH}
    export APP_HOST=${APP_HOST_SEARCH}
    export APP_NODES=${APP_NODES_SEARCH}
    export APP_RESERVED_IP=${APP_RESERVED_IP_SEARCH}
    export HTTP_PASSWD_ADMIN=${HTTP_PASSWD}
    export HTTP_PASSWD=dummy
    echo "▶️   k8s deployment of ${APP_ID} to ${TARGET}";
    (cd judilibre-search && \
        ./scripts/init_deps.sh && \
        ./scripts/deploy_k8s_services.sh && \
        ./scripts/test_minimal.sh && cd .. ) || exit 1;
    #
    #final test for API admin
    export HTTP_PASSWD=${HTTP_PASSWD_ADMIN};
    export APP_HOST=${APP_HOST_ADMIN};
    ./scripts/test_minimal.sh || exit 1;
done
