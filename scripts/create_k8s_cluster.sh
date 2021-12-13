#!/bin/bash

sudo echo -n

if [ ! -z "${ENV_FILE}" ];then
    export $(cat ${TARGET} | sed 's/#.*//g' | xargs);
fi;

if [ ! -z "${ENV_VARS}" ];then
    export ${ENV_VARS};
fi;

if [ -z "${KUBE_INSTALL_LOG}" ];then
    export KUBE_INSTALL_LOG=$(pwd)/k8s-$(date +%Y%m%d_%H%M).log;
fi;

#install bins if needed
./scripts/check_install.sh

[ -z "${SCW_KUBE_SECRET_TOKEN}" -o -z "${SCW_KUBE_PROJECT_ID}" -o -z "${SCW_KUBE_PROJECT_NAME}" ] && \
    echo "Impossible de créer une instance sans SCW_KUBE_PROJECT_NAME, SCW_KUBE_PROJECT_ID ou SCW_SECRET_TOKEN" && exit 1;

if [ -z "${KUBE_CONFIG}" ];then
    export KUBE_CONFIG=${HOME}/.kube/kubeconfig-${SCW_PROJECT_NAME}-${SCW_ZONE}.yaml
fi;

: ${SCW_CNI:="cilium"}
: ${SCW_FLAVOR:="GP1-XS"}
: ${SCW_REGION:="fr-par"}
: ${SCW_KUBE_API:="https://api.scaleway.com/k8s/v1/regions/${SCW_REGION}/clusters"}
: ${SCW_KUBE_NODES:=3}
: ${SCW_KUBE_VERSION:="1.23.0"}

: ${SCW_ZONE:="fr-par-1"}
: ${SCW_SERVER_API:="https://api.scaleway.com/instance/v1/zones/${SCW_ZONE}/servers"}
: ${SCW_SECURITYGROUP_API:="https://api.scaleway.com/instance/v1/zones/${SCW_ZONE}/security_groups"}
: ${KUBE_INGRESS:='nginx'}

if [ "${APP_GROUP}" == "monitor" ];then
    export SCW_KUBE_CLUSTERCONFIG="{'project_id':'${SCW_KUBE_PROJECT_ID}', 'name':'${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}',
                            'cni': '${SCW_CNI}', 'version':'${SCW_KUBE_VERSION}',
                            'auto_upgrade':{'enable':true,'maintenance_window':{'start_hour':2, 'day':'any'}},
                            'pools':[{'name':'default','node_type':'${SCW_FLAVOR}',
                                    'autoscaling':true,'size':${SCW_KUBE_NODES},'autohealing':true,'zone':'${SCW_ZONE}'}]
                            }"
else
    export SCW_KUBE_CLUSTERCONFIG="{'project_id':'${SCW_KUBE_PROJECT_ID}', 'name':'${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}',
                            'ingress':'${KUBE_INGRESS}', 'cni': '${SCW_CNI}', 'version':'${SCW_KUBE_VERSION}',
                            'auto_upgrade':{'enable':true,'maintenance_window':{'start_hour':2, 'day':'any'}},
                            'pools':[{'name':'default','node_type':'${SCW_FLAVOR}',
                                    'autoscaling':true,'size':${SCW_KUBE_NODES},'autohealing':true,'zone':'${SCW_ZONE}'}]
                            }"
fi;

export SCW_KUBE_CLUSTERCONFIG=$(echo $SCW_KUBE_CLUSTERCONFIG | tr "'" '"' | jq -c '.')

if [ -z "${SCW_KUBE_ID}" ];then
    export SCW_KUBE_ID=$(curl -s ${SCW_KUBE_API} -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" \
                            -H "Content-Type: application/json" \
                            -d ${SCW_KUBE_CLUSTERCONFIG} | jq -r '.id' | grep -v null)

    if [ ! -z "${SCW_KUBE_ID}" ]; then
        echo "🚀  k8s ${SCW_KUBE_VERSION} cluster ${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}";
    else
        echo -e "\e[31m❌  k8s ${SCW_KUBE_VERSION} cluster ${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE} !" && exit 1;
    fi;
else
    echo "✓   k8s ${SCW_KUBE_VERSION} cluster ${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}"
fi

timeout=${START_TIMEOUT}
ret=1;\
until [ "$timeout" -le 0 -o "$ret" -eq "0" ] ; do
        (curl -s ${SCW_KUBE_API}/${SCW_KUBE_ID} -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" | jq -r '.status' | grep -q 'ready');
        ret=$? ;
        if [ "$ret" -ne "0" ] ; then printf "\r\033[2K%03d Wait for k8s ${SCW_KUBE_ID} to be ready" $timeout ; fi ;
        ((timeout--)); sleep 1 ;
done ;
echo -e "\r\033[2K✓   k8s cluster ${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE} ${SCW_KUBE_ID} is ready";

if (curl -s "${SCW_KUBE_API}/${SCW_KUBE_ID}/kubeconfig?dl=1" -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" > ${KUBECONFIG});then
    echo "✓   k8s kubeconfig ${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE} downloaded";
fi

# wait first ip (first node to be ready)
# we use workaround using server API as k8s API is very slow to get IP
until [ "$timeout" -le 0 -o "${SCW_DNS_UPDATE_IP}" != "" ] ; do
        if [ -z "${SCW_K8S_NODENAME}" ]; then
            export SCW_K8S_NODENAME=$(curl -s "${SCW_KUBE_API}/${SCW_KUBE_ID}/nodes" -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" | jq -cr '.nodes[0].name' | grep -v null)
        fi;
        if [ -z "${SCW_K8S_NODENAME}" ]; then
            printf "\r\033[2K%03d Wait for k8s ${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE} first node" $timeout ;
        else
            export SCW_DNS_UPDATE_IP=$(curl -s "${SCW_SERVER_API}" -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" | jq -cr '.servers[] | select(.name=="'${SCW_K8S_NODENAME}'") | .public_ip.address' | grep -v null);
             if [ -z "${SCW_DNS_UPDATE_IP}" ] ; then printf "\r\033[2K%03d Wait for k8s node ${SCW_K8S_NODENAME} to get IP" $timeout ; fi ;
        fi;
        ((timeout--)); sleep 1 ;
done ;

if [ -z "${SCW_DNS_UPDATE_IP}" ];then
    echo -e "\r\033[2K\e[31m❌  k8s cluster ${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE} failed to get public IP" && exit 1;
fi

export SCW_KUBE_SECURITYGROUP_ID=$(curl -s "${SCW_SERVER_API}" -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" | jq -cr '.servers[] | select(.name=="'${SCW_K8S_NODENAME}'") | .security_group.id' 2>&1)

if [ ! -z "${SCW_KUBE_SECURITYGROUP_ID}" ];then
    SCW_RULE_443='{"protocol":"TCP","direction":"inbound","action":"drop","ip_range": "0.0.0.0/0","dest_port_from": 443}'
    SCW_RULE_80='{"protocol":"TCP","direction":"inbound","action":"drop","ip_range": "0.0.0.0/0","dest_port_from": 80}'
    if (    (curl -s -XPUT "${SCW_SECURITYGROUP_API}/${SCW_KUBE_SECURITYGROUP_ID}" -H "Content-Type: application/json" -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" -d "{\"stateful\":true}" >> ${KUBE_INSTALL_LOG} 2>&1) \
         && (curl -s -XPOST "${SCW_SECURITYGROUP_API}/${SCW_KUBE_SECURITYGROUP_ID}/rules" -H "Content-Type: application/json" -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" -d "${SCW_RULE_443}" >> ${KUBE_INSTALL_LOG} 2>&1) \
         && (curl -s -XPOST "${SCW_SECURITYGROUP_API}/${SCW_KUBE_SECURITYGROUP_ID}/rules" -H "Content-Type: application/json" -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" -d "${SCW_RULE_80}"  >> ${KUBE_INSTALL_LOG} 2>&1) \
    );then
            echo -e "\r\033[2K🚀  k8s security group";
    else
        echo -e "\r\033[2K\e[31m❌  k8s security group !" && exit 1;
    fi
else
    echo -e "\r\033[2K\e[31m❌  k8s no security group !!" && exit 1;
fi

echo -e "\r\033[2K✓   k8s cluster ${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE} has public IP ${SCW_DNS_UPDATE_IP}";

## update DNS with SCW_DNS_UPDATE_IP
# for host in ${APP_HOST} ${APP_HOST_SEARCH}; do
#     export APP_HOST=${host};
#     ./scripts/update_dns.sh;
# done;


