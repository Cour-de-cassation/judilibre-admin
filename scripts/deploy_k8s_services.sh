#!/bin/bash

#set up services to start
if [ -z "${APP_DNS}" ]; then
        K8S_SERVICES="namespace elasticsearch service deployment ingress";
        if [ ! -f "$(which minikube)" ]; then
                (curl -s -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && ./minikube start;)
        else
                ( (minikube status > /dev/null 2>&1 && echo "✓   using minikube") || minikube start);
        fi;
else
        K8S_SERVICES="namespace elasticsearch service deployment certificate ingressroute traefik-ingress"
fi;

export OS_TYPE=$(cat /etc/os-release | grep -E '^NAME=' | sed 's/^.*debian.*$/DEB/I;s/^.*ubuntu.*$/DEB/I;s/^.*fedora.*$/RPM/I;s/.*centos.*$/RPM/I;')

if [ -z "${VERSION}" ];then\
        export VERSION="$(cat package.json | jq -r '.version')-$(git rev-parse --short HEAD)"
fi

if [ ! -f "/usr/bin/envsubst" ]; then
        if [ "${OS_TYPE}" = "DEB" ]; then
                apt-get install -yqq gettext;
        fi;
        if [ "${OS_TYPE}" = "RPM" ]; then
                sudo yum install -y gettext;
        fi;
fi;

if [ -z "${KUBECTL}"]; then
        if [ ! -f "$(which kubectl)" ]; then
                export KUBECTL=$(pwd)/kubectl
                curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" > ${KUBECTL}
                chmod +x ${KUBECTL};
        else
                export export KUBECTL=$(which kubectl)
        fi;
fi

#install elasticsearch kube controller
(${KUBECTL} get elasticsearch > /dev/null 2>&1 && echo "✓   elasticsearch k8s controller") \
        || (${KUBECTL} apply -f https://download.elastic.co/downloads/eck/1.5.0/all-in-one.yaml && echo "✓🚀 elasticsearch k8s controller")

#create common services (tls chain based on traefik hypothesis, web exposed k8s like Scaleway, ovh ...)
for resource in ${K8S_SERVICES}; do
        NAMESPACE=$(envsubst < k8s/${resource}.yaml | grep -e '^  namespace:' | sed 's/.*:\s*//;s/\s*//;');
        RESOURCENAME=$(envsubst < k8s/${resource}.yaml | grep -e '^  name:' | sed 's/.*:\s*//;s/\s*//');
        (${KUBECTL} get ${resource} --namespace=${NAMESPACE} 2>&1 | grep -v 'No resources' | grep -q ${RESOURCENAME} && echo "✓   ${resource} ${NAMESPACE}/${RESOURCENAME}") || \
        ( (envsubst < k8s/${resource}.yaml | ${KUBECTL} apply -f - > /dev/null) && (echo "🚀  ${resource} ${NAMESPACE}/${RESOURCENAME}") ) \
        || ( echo -e "\e[31m❌  ${resource} ${NAMESPACE}/${RESOURCENAME} !\e[0m" && exit 1);
        if [ "$?" -ne "0" ]; then exit 1;fi;
done;

# wait for k8s pods to be ready
timeout=${START_TIMEOUT} ; ret=1 ;\
until [ "$timeout" -le 0 -o "$ret" -eq "0" ] ; do\
        ( ${KUBECTL} get pod --namespace=${APP_GROUP} | egrep "${APP_ID}|${APP_GROUP}-es" | grep -vq '0/' );\
        ret=$? ; \
        if [ "$ret" -ne "0" ] ; then echo -en "\r\033[2KWait for service ${APP_ID} to be ready ... $timeout" ; fi ;\
        ((timeout--)); sleep 1 ; \
done ;

if [ "$ret" -ne "0" ];then
        (echo -en "\r\033[2K\e[31m❌  all service are not ready !\e[0m\n" && ${KUBECTL} get pod --namespace=${APP_GROUP} && exit 1)
else
        (echo -en "\r\033[2K✅  All resources are ready !\n")
fi;
