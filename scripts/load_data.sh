#!/bin/bash

./scripts/check_install.sh

: ${DATA_DIR:=$(pwd)/judilibre-sder/src/data/export}
if [ ! -d ${DATA_DIR} ];then
    if ! (git clone https://oauth2:${GIT_TOKEN}@github.com/Cour-de-cassation/judilibre-sder > /dev/null 2>&1); then
        echo -e "e[31m❌ ${IMPORT_MSG} batch $file failed, couldn't clone git repository \e[0m" && exit 1;
    fi;
fi;

: ${IMPORT_ROUTE:=import}
: ${IMPORT_SIZE:=100}
: ${IMPORT_LIMIT:=1000000}
: ${IMPORT_MSG:=injecting}
IMPORT_DIR=.bulk-${KUBE_ZONE}-${GIT_BRANCH}
rm -rf ${IMPORT_DIR} > /dev/null 2>&1
mkdir -p ${IMPORT_DIR}
(find -L ${DATA_DIR}/ -type f -iname '*.json' | head -${IMPORT_LIMIT} | xargs jq -c '. + {"type":"arret"}' \
    | awk 'BEGIN{l=0;s=1;b="";n}{if (b==""){b=$0}else{b=b "," $0};if (s == '"${IMPORT_SIZE}"') {printf "\033[2K\r…   preparing batches %d", l > "/dev/stderr";print "{\"id\": \"" l++ "\", \"decisions\": [" b "]}";s=0;b=""};s++}END{if (b!=""){print "{\"id\": \"" l++ "\", \"decisions\": [" b "]}"}}' \
    | split -a8 -l1 - ${IMPORT_DIR}/lot_decisions_ && echo -en  "\033[2K\r✓   prepared batch of size ${IMPORT_SIZE}") || \
    (echo -e "\033[2K\re[31m❌ preparation of batch failed" && exit 1);

BATCH_NUMBER=$(ls ${IMPORT_DIR}/ | wc -l)
BATCH=0
for file in ${IMPORT_DIR}/*;do
    ((BATCH++))
    if [ ! $(curl -vvv --fail -k ${APP_SCHEME}://admin:${HTTP_PASSWD}@${APP_HOST}:${APP_PORT}/${IMPORT_ROUTE} -H "Content-type:application/json" -d @$file > $file.log 2>&1) ];then
        echo -en "\033[2K\r✓   ${IMPORT_MSG} batch (${BATCH}/${BATCH_NUMBER})"
    else
        echo -e "e[31m❌ ${IMPORT_MSG} batch $file failed, cf $file.log! \e[0m" && exit 1;
    fi;
done;
