#!/bin/bash


if [ -z "${ENV_FILE_SRC}" ];then
    echo -e "\e[31m❌  your must provide ENV_FILE_SRC to clone data from a source" && exit 1;
fi

if [ -z "${ENV_FILES_DST}" ];then
    echo -e "\e[31m❌  your must provide ENV_FILES_DST to clone data to destination(s)" && exit 1;
fi

if [ -z "${KUBE_INSTALL_LOG}" ];then
    export KUBE_INSTALL_LOG=$(pwd)/k8s-$(date +%Y%m%d_%H%M).log;
fi;

if [ -z "${KUBECTL}" ];then
    export KUBECTL=$(which kubectl);
fi

# pause snapshots
for ENV in ${ENV_FILE_SRC} ${ENV_FILES_DST}; do
    (
        export $(cat ${ENV} | sed 's/#.*//g' | xargs);
    )
done;

: ${SCW_REGION:="fr-par"}
# export RCLONE_CONFIG_S3_TYPE=s3
# export RCLONE_CONFIG_S3_ACCESS_KEY_ID=$(export $(cat ${ENV_FILE_SRC} | sed 's/#.*//g' | xargs);echo $SCW_DATA_ACCESS_KEY)
# export RCLONE_CONFIG_S3_SECRET_ACCESS_KEY=$(export $(cat ${ENV_FILE_SRC} | sed 's/#.*//g' | xargs);echo $SCW_DATA_SECRET_KEY)
# export RCLONE_CONFIG_S3_ENV_AUTH=false
# export RCLONE_CONFIG_S3_ENDPOINT=s3.${SCW_REGION}.scw.cloud
# export RCLONE_CONFIG_S3_REGION=${SCW_REGION}
# export RCLONE_CONFIG_S3_SERVER_SIDE_ENCRYPTION=
# export RCLONE_CONFIG_S3_FORCE_PATH_STYLE=false
# export RCLONE_CONFIG_S3_LOCATION_CONSTRAINT=
# export RCLONE_CONFIG_S3_STORAGE_CLASS=
# export RCLONE_CONFIG_S3_ACL=private

S3_SRC=$(export $(cat ${ENV_FILE_SRC} | sed 's/#.*//g' | xargs); echo ${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}-${KUBE_NAMESPACE})
for ENV_DST in ${ENV_FILES_DST};do
    S3_DST=$(export $(cat ${ENV_DST} | sed 's/#.*//g' | xargs); echo ${SCW_KUBE_PROJECT_NAME}-${SCW_ZONE}-${KUBE_NAMESPACE});
    # echo -n "➡️   s3 copy ${S3_SRC} to ${S3_DST}";
    # (rclone sync s3://${S3_SRC} s3://${S3_DST} > ${KUBE_INSTALL_LOG} 2>&1) && echo "\r\033[2K✓   s3 copy ${S3_SRC} to ${S3_DST}" || echo -e "\r\e[31m❌  s3 copy ${S3_SRC} to ${S3_DST}";
    (
        export $(cat ${ENV_DST} | sed 's/#.*//g' | xargs);
        (cat k8s/snapshots.yaml | envsubst | ${KUBECTL} delete -f - > ${KUBE_INSTALL_LOG} 2>&1) && echo "✓   stop cronjob for snapshots ${KUBE_NAMESPACE}"
        export ELASTIC_ADMIN_PASSWORD=$(${KUBECTL} get secret --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')
        export ELASTIC_NODE="https://elastic:${ELASTIC_ADMIN_PASSWORD}@localhost:9200"
        ELASTIC_INDICES=$(${KUBECTL} -n ${KUBE_NAMESPACE} exec -it ${APP_GROUP}-es-default-0 -- curl -k ${ELASTIC_NODE}/_cat/indices 2>&1 | grep judilibre | awk '{print $3}' )
        for ELASTIC_INDEX_TO_DELETE in $ELASTIC_INDICES; do
            (${KUBECTL} -n ${KUBE_NAMESPACE} exec -it ${APP_GROUP}-es-default-0 -- curl -k -XDELETE ${ELASTIC_NODE}/${ELASTIC_INDEX_TO_DELETE} > ${KUBE_INSTALL_LOG} 2>&1) && echo "✓   clean index ${ELASTIC_INDEX_TO_DELETE} on ${KUBE_NAMESPACE}";
        done;
        ELASTIC_REPOSITORY="{
                'type': 's3',
                'settings': {
                        'bucket': '${S3_SRC}',
                        'region': '${SCW_REGION}',
                        'endpoint': 's3.${SCW_REGION}.scw.cloud'
                }
        }"
        ELASTIC_REPOSITORY=$(echo ${ELASTIC_REPOSITORY} | tr "'" '"' | jq -c '.')
        if (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k -XPUT "${ELASTIC_NODE}/_snapshot/${S3_SRC}" -H 'Content-Type: application/json' -d "${ELASTIC_REPOSITORY}" > ${KUBE_INSTALL_LOG} 2>&1); then
            echo "✓   elasticsearch set backup SRC repository as ${S3_SRC}";
            ELASTIC_SNAPSHOT=$(${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k "${ELASTIC_NODE}/_cat/snapshots/${S3_SRC}" 2>&1 | grep SUCCESS | tail -1 | awk '{print $1}');
            retries=15;
            while [ -z "${ELASTIC_SNAPSHOT}" -a "$retries" -gt 0 ];do
                ((retries--));
                sleep 1;
                ${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k -XDELETE "${ELASTIC_NODE}/_snapshot/${S3_SRC}" > ${KUBE_INSTALL_LOG} 2>&1;
                ${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k -XPUT "${ELASTIC_NODE}/_snapshot/${S3_SRC}" -H 'Content-Type: application/json' -d "${ELASTIC_REPOSITORY}" > ${KUBE_INSTALL_LOG} 2>&1;
                ELASTIC_SNAPSHOT=$(${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k "${ELASTIC_NODE}/_cat/snapshots/${S3_SRC}" 2>&1 | grep SUCCESS | tail -1 | awk '{print $1}');
            done;
            if [ -z "${ELASTIC_SNAPSHOT}" ]; then
                    echo -e "\e[31m❌  elasticsearch could retrive backup from ${S3_SRC} !\e[0m";
            else
                if (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k -XPOST "${ELASTIC_NODE}/_snapshot/${S3_SRC}/${ELASTIC_SNAPSHOT}/_restore" -H 'Content-Type: application/json' -d '{"indices":"'${ELASTIC_INDEX}'"}' > ${KUBE_INSTALL_LOG} 2>&1);then
                        echo "🔄  elasticsearch backup ${ELASTIC_SNAPSHOT} restored from ${S3_SRC} to ${KUBE_NAMESPACE}";
                else
                        echo -e "\e[31m❌  elasticsearch backup ${ELASTIC_SNAPSHOT} not restored from ${S3_SRC} to ${KUBE_NAMESPACE} !\e[0m";
                fi;
            fi
            (${KUBECTL} exec --namespace=${KUBE_NAMESPACE} ${APP_GROUP}-es-default-0 -- curl -s -k -XDELETE "${ELASTIC_NODE}/_snapshot/${S3_SRC}" > ${KUBE_INSTALL_LOG} 2>&1) && echo "✓   elasticsearch remove backup SRC repository";
            (cat k8s/snapshots.yaml | envsubst | ${KUBECTL} apply -f - > ${KUBE_INSTALL_LOG} 2>&1) && echo "✓   re-enable cronjob for snapshots ${KUBE_NAMESPACE}"
        fi;
        timeout=360 ;
        ret=1 ;
        until [ "$timeout" -le 0 -o "$ret" -eq "0" ] ; do
                (${KUBECTL} -n ${KUBE_NAMESPACE} exec -it ${APP_GROUP}-es-default-0 -- curl -k ${ELASTIC_NODE}/_cat/indices 2>&1| grep ${ELASTIC_INDEX} | grep -q green);
                ret=$? ;
                if [ "$ret" -ne "0" ] ; then printf "\r\033[2K%03d Wait for index ${ELASTIC_INDEX} to be ready" $timeout ; fi ;
                ((timeout--)); sleep 1 ;
        done ;
        echo -en "\r\033[2K";
    )
done