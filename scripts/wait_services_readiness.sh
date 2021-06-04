# wait for k8s pods to be ready
: "${KUBECTL:=kubectl}"

timeout=${START_TIMEOUT} ; ret=0 ;\
until [ "$timeout" -le 0 -o "$ret" -eq "1" ] ; do\
        ( ${KUBECTL} get pod --namespace=${APP_GROUP} | egrep "${APP_ID}|${APP_GROUP}-es" | grep -q '0/1' );\
        ret=$? ; \
        if [ "$ret" -ne "1" ] ; then echo -en "\r\033[2KWait for service ${APP_ID} to be ready ... $timeout" ; fi ;\
        ((timeout--)); sleep 1 ; \
done ;

if [ "$ret" -ne "1" ];then
        (echo -en "\r\033[2K\e[31m❌  all service are not ready !\e[0m\n" && ${KUBECTL} get pod --namespace=${APP_GROUP} && exit 1)
fi;

ret=0;ok=""
until [ "$timeout" -le 0 -o ! -z "$ok" ] ; do
        lb=$(${KUBECTL} get service --namespace=kube-system | grep -i loadbalancer | grep -v pending | awk '{print $1}');
        if [ ! -z "$lb" ]; then
            ret=$(${KUBECTL} describe service/${lb} --namespace=kube-system | grep Endpoints | awk 'BEGIN{s=0}($2){s++}END{printf s}');
        fi;
        if [ "$ret" -eq "0" ] ; then
            echo -en "\r\033[2KWait for Loadbalancer to be ready ... $timeout";
        else
            if (curl -s -o /dev/null -k -XGET ${APP_SCHEME}://${APP_HOST}:${APP_PORT}); then
                ok="ok";
            else
                echo -en "\r\033[2KWait for Endpoints to be ready ... $timeout";
            fi;
        fi;
        ((timeout--)); sleep 1 ;
done ;

if [ -z "$ok" ];then
        (echo -en "\r\033[2K\e[31m❌  all service are not ready !\e[0m\n" && (${KUBECTL} get service --namespace=kube-system | grep -i loadbalancer) && exit 1)
else
        (echo -en "\r\033[2K✅  All resources are ready !\n")
fi;

