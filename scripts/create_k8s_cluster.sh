#!/bin/bash
[ -z "${SCW_KUBE_SECRET_TOKEN}" -o -z "${SCW_KUBE_PROJECT_ID}" -o -z "${SCW_KUBE_PROJECT_NAME}" ] && \
    echo "Impossible de créer une instance sans SCW_PROJECT_NAME, SCW_PROJECT_ID ou SCW_SECRET_TOKEN" && exit 1;

: ${SCW_CNI:="cilium"}
: ${SCW_FLAVOR:="GP1-XS"}
: ${SCW_KUBE_API:="https://api.scaleway.com/k8s/v1/regions/fr-par/clusters"}
: ${SCW_DNS_API:="https://api.scaleway.com/domain/v2beta1/dns-zones"}
: ${SCW_KUBE_NODES:=3}
: ${SCW_KUBE_VERSION:="1.21.1"}
: ${SCW_ZONE:="fr-par-1"}
: ${KUBE_INGRESS:='nginx'}

SCW_KUBE_CLUSTERCONFIG="{'project_id':'${SCW_KUBE_PROJECT_ID}', 'name':'${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}',
                         'ingress':'${KUBE_INGRESS}', 'cni': '${SCW_CNI}', 'version':'${SCW_KUBE_VERSION}',
                         'auto_upgrade':{'enable':true,'maintenance_window':{'start_hour':2, 'day':'any'}},
                         'pools':[{'name':'default','node_type':'${SCW_FLAVOR}',
                                'autoscaling':true,'size':${SCW_KUBE_NODES},'autohealing':true,'zone':'${SCW_ZONE}'}]
                        }"

SCW_KUBE_CLUSTERCONFIG=$(echo $SCW_KUBE_CLUSTERCONFIG | tr "'" '"' | jq -c '.')

SCW_KUBE_ID=$(curl -s ${SCW_KUBE_API} -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" \
                        -H "Content-Type: application/json" \
                        -d ${SCW_KUBE_CLUSTERCONFIG} | jq -r '.id' | grep -v null)

if [ ! -z "${SCW_KUBE_ID}" ]; then
    echo "🚀  k8s cluster created";
else
    echo -e "\e[31m❌  k8s creation failed" && exit 1;
fi;

timeout=${START_TIMEOUT}
ret=1;\
until [ "$timeout" -le 0 -o "$ret" -eq "0" ] ; do
        (curl -s ${SCW_KUBE_API}/${SCW_KUBE_ID} -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" | jq -r '.status' | grep -q 'ready');
        ret=$? ;
        if [ "$ret" -ne "0" ] ; then printf "\r\033[2K%03d Wait for k8s ${SCW_KUBE_ID} to be ready" $timeout ; fi ;
        ((timeout--)); sleep 1 ;
done ;
echo -e "\r\033[2K✓   k8s cluster ${SCW_KUBE_ID} is ready";

: ${KUBECONFIG:="${HOME}/.kube/kubeconfig-${SCW_PROJECT_NAME}-${SCW_ZONE}.yaml"}

if (curl -s "${SCW_KUBE_API}/${SCW_KUBE_ID}/kubeconfig?dl=1" -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" > ${KUBECONFIG});then
    echo "✓   k8s kubeconfig downloaded";
fi

until [ "$timeout" -le 0 -o "${SCW_KUBE_IP}" != "" ] ; do
        SCW_KUBE_IP=$(curl -s "${SCW_KUBE_API}/${SCW_KUBE_ID}/nodes" -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" | jq -cr '.nodes[].public_ip_v4' | awk '(NF)' | head -1);
        if [ "${SCW_KUBE_IP}" == "" ] ; then printf "\r\033[2K%03d Wait for k8s ${SCW_KUBE_ID} to get IP" $timeout ; fi ;
        ((timeout--)); sleep 1 ;
done ;

if [ -z "${SCW_KUBE_IP}" ];then
    echo -e "\e[31m❌  k8s failed to get public IP" && exit 1;
fi

echo -e "\r\033[2K✓   k8s cluster got public IP ${SCW_KUBE_IP}";


### DNS update
SCW_DNS_ZONE=$(curl -s "${SCW_DNS_API}" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}"  | jq -r '.dns_zones[0].domain')

if [ -z "${SCW_DNS_ZONE}" ];then
    echo;
    echo -e "\e[31m❌  DNS - failed to get dns zone" && exit 1;
fi

APP_DNS_SHORT=$(echo ${APP_HOST} | sed "s/.${SCW_DNS_ZONE}//")

SCW_DNS_RECORD_IP=$(curl -s "${SCW_DNS_API}/${SCW_DNS_ZONE}/records" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}"  | jq -cr '.records[] | select( .name == "'${APP_DNS_SHORT}'") | .data')

if [ ! -z "${SCW_DNS_RECORD_IP}" ];then
    if [ "${SCW_DNS_RECORD_IP}" != "${SCW_KUBE_IP}" ]; then
        SCW_DNS_RECORD_ID=$(curl -s "${SCW_DNS_API}/${SCW_DNS_ZONE}/records" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}"  | jq -cr '.records[] | select( .name == "'${APP_DNS_SHORT}'") | .id');
        SCW_DNS_DELETE_RECORD="{'changes':[{'delete':{'id':'${SCW_DNS_RECORD_ID}'}}]}";
        SCW_DNS_DELETE_RECORD=$(echo $SCW_DNS_DELETE_RECORD | tr "'" '"' );
        if (curl -s -XPATCH "${SCW_DNS_API}/${SCW_DNS_ZONE}/records" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}" -d ${SCW_DNS_DELETE_RECORD} | grep -q records);then
            echo -e "✓   DNS - deleted previous record for ${APP_DNS_SHORT}";
        else
            echo -e "\e[31m❌  DNS - failed deleting previous record for ${APP_DNS_SHORT}" && exit 1;
        fi;
    else
        echo -e "✓   DNS - record ${APP_DNS_SHORT} already exists";
        SKIP=true
    fi;
fi

if [ -z "${SKIP}" ]; then
    SCW_DNS_RECORD="{'changes':[{'add':{
                        'records': [{
                            'ttl': 600,
                            'type':'A','name':'${APP_DNS_SHORT}','data':'${SCW_KUBE_IP}'
                            }]
                        }}]}"

    SCW_DNS_RECORD=$(echo $SCW_DNS_RECORD | tr "'" '"' | jq -c '.')

    if (curl -s -XPATCH "${SCW_DNS_API}/${SCW_DNS_ZONE}/records" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}" -d ${SCW_DNS_RECORD} | grep -q ${APP_DNS_SHORT});then
        echo -e "🚀  DNS - set ${SCW_KUBE_IP} to ${APP_DNS_SHORT}";
    else
        echo -e "\e[31m❌  DNS - failed deleting previous record for ${APP_DNS_SHORT}" && exit 1;
    fi
fi
