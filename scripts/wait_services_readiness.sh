# wait for k8s pods to be ready
: "${KUBECTL:=kubectl}"

if [ "${APP_GROUP}" == "judilibre-prive" ]; then
        if [ "${KUBE_ZONE}" == "local" ];then
                APP_DB=mongodb-0;
        fi;
else
        APP_DB=${APP_GROUP}-es;
fi

: ${START_TIMEOUT:=60}
timeout=${START_TIMEOUT} ;
for POD in ${APP_ID} ${APP_DB}; do
    ret=1 ;\
    until [ "$timeout" -le 0 -o "$ret" -eq "0" ] ; do\
            status=$(${KUBECTL} get pod --namespace=${KUBE_NAMESPACE} | grep ${POD} | awk '{print $2}');
            (echo $status | egrep -v '0/1|0/2|1/2' | egrep -q '1/1|2/2' );\
            ret=$? ; \
            if [ "$ret" -ne "0" ] ; then printf "\r\033[2K%03d Wait for service ${POD} to be ready" $timeout ; fi ;\
            ((timeout--)); sleep 1 ; \
    done ;
done;

if [ "$ret" -ne "0" ]; then
        echo -en "\r\033[2K\e[31m❌  all service are not ready !\e[0m\n";
        ${KUBECTL} get pod --namespace=${KUBE_NAMESPACE};
        exit 1;
else
        (echo -en "\r\033[2K✓   all pods are ready\n")
fi;

