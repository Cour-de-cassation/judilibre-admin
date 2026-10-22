#!/bin/bash

export GIT_OPS=judilibre-ops
export DEPS_SRC=$(pwd)/${GIT_OPS}
export SCRIPTS_SRC=${DEPS_SRC}/scripts
export KUBE_SRC=${DEPS_SRC}/k8s

# clone
if [ ! -d "${SCRIPTS_SRC}" ];then
    [ "${#GIT_TOKEN}" -gt 10 ] || { echo -e "\e[31m❌ GIT_TOKEN vide ou invalide (length=${#GIT_TOKEN}) \e[0m"; exit 1; }
    for i in 1 2 3; do
        git -c http.version=HTTP/1.1 -c http.extraheader="AUTHORIZATION: basic $(echo -n "x-access-token:${GIT_TOKEN}" | base64 -w0)" clone https://github.com/Cour-de-cassation/${GIT_OPS}.git > /dev/null && break
        echo "→ Clone échoué (tentative $i/3), nouvel essai dans 10s..."
        rm -rf ${GIT_OPS}; sleep 10
    done
    [ -d "${SCRIPTS_SRC}" ] || { echo -e "\e[31m❌ init failed, couldn't clone git ${GIT_OPS} repository \e[0m"; exit 1; }
fi;

# scripts

for file in $(ls ${SCRIPTS_SRC}); do
    if [ ! -f "./scripts/$file" ]; then
        ln -s ${SCRIPTS_SRC}/$file ./scripts/$file;
    fi;
done;

# kube configs
if [ ! -d "k8s/" ];then
    ln -s ${KUBE_SRC} ./k8s;
fi;

