#!/bin/bash

if [ -z ENV_FILES ];then
    echo -e "\e[31m❌  your must provide ENV_FILES to deploy targets" && exit 1;
fi

if [ ! -d judilibre-search ];then
    git clone https://github.com/Cour-de-cassation/judilibre-search;
fi;

for TARGET in $ENV_FILES;do
    echo "✓   configuring env from ${TARGET}";
    export export $(cat ${TARGET} | sed 's/#.*//g' | xargs)
    echo "✓   preparing deployment of ${APP_ID} to ${TARGET}";
    (./scripts/create_k8s_cluster.sh && ./scripts/deploy_k8s_services.sh && ./scripts/test_minimal.sh) || exit 1;

    echo "✓   preparing deployment of ${APP_ID} to ${TARGET}";
    export APP_ID=${APP_ID_SEARCH}
    export APP_HOST=${APP_HOST_SEARCH}
    export APP_NODES=${APP_NODES_SEARCH}
    export HTTP_PASSWD=dummy
    (cd judilibre-search && \
        ./scripts/init_deps.sh && \
        ./scripts/deploy_k8s_services.sh && \
        ./scripts/test_minimal.sh && cd .. ) || exit 1;
done;
