#!/bin/bash
[ -z "${SCW_KUBE_SECRET_TOKEN}" -o -z "${SCW_KUBE_PROJECT_ID}" -o -z "${SCW_KUBE_PROJECT_NAME}" ] && \
    echo "Impossible de créer une instance sans SCW_PROJECT_NAME, SCW_PROJECT_ID ou SCW_SECRET_TOKEN" && exit 1;

: ${SCW_CNI:="cilium"}
: ${SCW_FLAVOR:="GP1-XS"}
: ${SCW_KUBE_API:="https://api.scaleway.com/k8s/v1/regions/fr-par/clusters"}
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
until [ "$timeout" -le 0 -o "$ret" -eq "0" ] ; do\
        (curl -s ${SCW_KUBE_API}/${SCW_KUBE_ID} -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" | jq -r '.status' | grep -q 'ready');
        ret=$? ; \
        if [ "$ret" -ne "0" ] ; then printf "\r\033[2K%03d Wait for k8s ${SCW_KUBE_ID} to be ready" $timeout ; fi ;\
        ((timeout--)); sleep 1 ; \
done ;
echo -e "\r\033[2K✓   k8s cluster ${SCW_KUBE_ID} is ready";

: ${KUBECONFIG:="${HOME}/.kube/kubeconfig-${SCW_PROJECT_NAME}-${SCW_ZONE}.yaml"}

if (curl -s "${SCW_KUBE_API}/${SCW_KUBE_ID}/kubeconfig?dl=1" -H "X-Auth-Token: ${SCW_KUBE_SECRET_TOKEN}" > ${KUBECONFIG});then
    echo "✓   k8s kubeconfig downloaded";
fi
