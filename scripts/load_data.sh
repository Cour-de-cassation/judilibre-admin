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
rm -rf .bulk > /dev/null 2>&1
mkdir .bulk
(find ${DATA_DIR}/ -type f | head -${IMPORT_LIMIT} | xargs jq -c '.' \
    | awk 'BEGIN{l=0;s=1;b=""}{if (b==""){b=$0}else{b=b "," $0};if (s == '"${IMPORT_SIZE}"') {print "{\"id\": \"" l++ "\", \"decisions\": [" b "]}";s=0;b=""};s++}END{if (b!=""){print "{\"id\": \"" l++ "\", \"decisions\": [" b "]}"}}' \
    | split -l1 - .bulk/lot_decisions_ && echo -n  "✓   prepared batch of size ${IMPORT_SIZE}") || \
    (echo -e "e[31m❌ preparation of batch failed" && exit 1);

BATCH_NUMBER=$(ls .bulk/ | wc -l)
BATCH=0
for file in .bulk/*;do
    ((BATCH++))
    if [ ! $(curl -vvv -k -XPOST ${APP_SCHEME}://${APP_HOST}:${APP_PORT}/${IMPORT_ROUTE} -H "Content-type:application/json" -d @$file > $file.log 2>&1) ];then
        echo -en "\033[2K\r✓   ${IMPORT_MSG} batch (${BATCH}/${BATCH_NUMBER})"
    else
        echo -e "e[31m❌ ${IMPORT_MSG} batch $file failed, cf $file.log! \e[0m" && exit 1;
    fi;
done;
