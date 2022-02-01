#!/bin/bash

export GIT_OPS=judilibre-ops
export DEPS_SRC=$(pwd)/${GIT_OPS}
export SCRIPTS_SRC=${DEPS_SRC}/scripts
export KUBE_SRC=${DEPS_SRC}/k8s

# clone
if [ ! -d "${SCRIPTS_SRC}" ];then
    if ! (git clone https://github.com/Cour-de-cassation/${GIT_OPS} > /dev/null 2>&1); then
        echo -e "\e[31m❌ init failed, couldn't clone git ${GIT_OPS} repository \e[0m" && exit 1;
        if [ "${GIT_BRANCH}" == "master" ]; then
            cd ${SCRIPTS_SRC};
            git checkout master;
            cd ..;
        fi;
    fi;
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

