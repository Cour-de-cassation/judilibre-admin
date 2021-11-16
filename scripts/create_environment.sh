#!/bin/bash

sudo echo -n

if [ -z "${KUBE_INSTALL_LOG}" ];then
    export KUBE_INSTALL_LOG=$(pwd)/k8s-$(date +%Y%m%d_%H%M).log;
fi;

if [ -z "${ENV_FILES}" ];then
    echo -e "\e[31m❌  your must provide ENV_FILES to deploy targets" && exit 1;
fi

if [ ! -d judilibre-search ];then
    git clone https://github.com/Cour-de-cassation/judilibre-search;
fi;

ENV_NUMBER=0

for TARGET in ${ENV_FILES};do
    ((ENV_NUMBER++))
    unset APP_RESERVED_IP APP_RESERVED_IP_SEARCH
    export $(cat ${TARGET} | sed 's/#.*//g' | xargs)
    (cd judilibre-search && git checkout ${GIT_BRANCH} >> ${KUBE_INSTALL_LOG} 2>&1)
    ##############################
    # step 1. reserve IPs of LB and update DNS
    echo "▶️   reserve IPs and set DNS for ${TARGET}";
    #
    # IP of admin API
    export SCW_LB_IP_API="https://api.scaleway.com/lb/v1/zones/${SCW_ZONE}/ips"
    export APP_HOST_ADMIN=${APP_HOST}
    if [ -z "${APP_RESERVED_IP}" ];then
        export APP_RESERVED_IP=$(curl -s -X POST "${SCW_LB_IP_API}" -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" -H "Content-Type: application/json" \
    -d "{\"project_id\":\"$SCW_KUBE_PROJECT_ID\"}" | jq -r .ip_address | grep -v null)
        if [ -z "${APP_RESERVED_IP}" ];then
            echo -e "\r\033[2K\e[31m❌  IP reservation failed for ${APP_ID} ![0m" && exit 1
        else
            echo "🚀  IP ${APP_RESERVED_IP} reserved for ${APP_ID}"
        fi;
    else
        echo "✓   IP ${APP_RESERVED_IP} reserved for ${APP_ID}"
    fi;
    export SCW_DNS_UPDATE_IP=${APP_RESERVED_IP}
    ./scripts/update_dns.sh || exit 1;
    if [ ! -z "${APP_HOST_ALTER}" ];then
        export APP_HOST=${APP_HOST_ALTER}
        ./scripts/update_dns.sh || exit 1;
    fi;
    #
    # IP of search API
    if [ -z "${APP_RESERVED_IP_SEARCH}" ];then
        export APP_RESERVED_IP_SEARCH=$(curl -s -X POST "${SCW_LB_IP_API}" -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" -H "Content-Type: application/json" \
    -d "{\"project_id\":\"$SCW_KUBE_PROJECT_ID\"}" | jq -r .ip_address | grep -v null)
        if [ -z "${APP_RESERVED_IP_SEARCH}" ];then
            echo -e "\r\033[2K\e[31m❌  IP reservation failed for ${APP_ID_SEARCH} ![0m" && exit 1
        else
            echo "🚀  IP ${APP_RESERVED_IP_SEARCH} reserved for ${APP_ID_SEARCH}"
        fi;
    else
        echo "✓   IP ${APP_RESERVED_IP_SEARCH} reserved for ${APP_ID_SEARCH}"
    fi;
    export APP_HOST=${APP_HOST_SEARCH}
    export SCW_DNS_UPDATE_IP=${APP_RESERVED_IP_SEARCH}
    ./scripts/update_dns.sh || exit 1;
    if [ ! -z "${APP_HOST_ALTER_SEARCH}" ];then
        export APP_HOST=${APP_HOST_ALTER_SEARCH}
        ./scripts/update_dns.sh || exit 1;
    fi;
    #
    unset SCW_DNS_UPDATE_IP
    export APP_HOST=${APP_HOST_ADMIN}
    export APP_HOST_ALTER_ADMIN=${APP_HOST_ALTER}
    if [ ${ENV_NUMBER} -eq 1 ];then
        export DYNAMIC_DNS_IP_ALTER=${APP_RESERVED_IP_SEARCH}
    else
        export DYNAMIC_DNS=${APP_HOST_ALTER_SEARCH}
        export DYNAMIC_DNS_IP=${APP_RESERVED_IP_SEARCH}
        export DYNAMIC_DNS_URL="${APP_SCHEME}://${APP_HOST_ALTER_SEARCH}/healthcheck"
        export DYNAMIC_DNS_TEST="disponible"
    fi;

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
    export APP_HOST_ALTER=${APP_HOST_ALTER_SEARCH}
    export APP_NODES=${APP_NODES_SEARCH}
    export APP_RESERVED_IP=${APP_RESERVED_IP_SEARCH}
    export HTTP_PASSWD_ADMIN=${HTTP_PASSWD}
    export HTTP_PASSWD=dummy
    echo "▶️   k8s deployment of ${APP_ID} to ${TARGET}";
    (cd judilibre-search && \
        ./scripts/init_deps.sh && \
        ./scripts/deploy_k8s_services.sh || exit 1);
    timeout=${START_TIMEOUT}
    for APP_HOST in ${APP_HOST_SEARCH} ${APP_HOST_ALTER_SEARCH};do
        ret=1 ;\
        until [ "$timeout" -le "0" -o "$ret" -eq "0" ] ; do
            (cd judilibre-search && ./scripts/test_minimal.sh > /dev/null 2>&1);
            ret=$?;
            if [ "$ret" -eq "1" ]; then exit 1; fi ;
            printf "\r\033[2K%03d Wait for certificate validation" $timeout;
            ((timeout--));sleep 1;
        done;
        printf "\r\033[2K";
        (cd judilibre-search && ./scripts/test_minimal.sh) || exit 1;
    done;

    #final test for API admin
    export HTTP_PASSWD=${HTTP_PASSWD_ADMIN};
    export APP_HOST=${APP_HOST_ADMIN};
    export APP_HOST_ALTER=${APP_HOST_ALTER_ADMIN};
    ./scripts/test_minimal.sh || exit 1;
    if [ ! -z "${APP_HOST_ALTER}" ];then
        export APP_HOST=${APP_HOST_ALTER};
        ./scripts/test_minimal.sh || exit 1;
    fi;
done;

# activate dynamic dns if *_ALTER
./scripts/update_dns_dynamic.sh || exit 1;
