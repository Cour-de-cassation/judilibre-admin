#!/bin/bash

./scripts/check_install.sh

for route in admin;do
  if curl -s -k --retry 5 --retry-delay 2 ${APP_SCHEME}://admin:${HTTP_PASSWD}@${APP_HOST}:${APP_PORT}/${route} | grep -q '"route":"GET /'${route}'"' ; then
      echo "✓   test api ${APP_SCHEME}://${HTTP_USER}:${HTTP_PASSWD}@${APP_HOST}:${APP_PORT}/${route}"
  else
      echo -e "\e[31m❌ ${route} !\e[0m"
      echo curl -k -XGET ${APP_SCHEME}://admin:${HTTP_PASSWD}@${APP_HOST}:${APP_PORT}/${route}
      curl -k -XGET ${APP_SCHEME}://admin:${HTTP_PASSWD}@${APP_HOST}:${APP_PORT}/${route}
      exit 1
  fi
done

: ${IMPORT_SIZE:=10}
: ${IMPORT_LIMIT:=100}
export IMPORT_SIZE
export IMPORT_LIMIT
export IMPORT_MSG="test api ${APP_SCHEME}://admin:${HTTP_PASSWD}@${APP_HOST}:${APP_PORT}/import"
if [ "${KUBE_ZONE}" == "local" ];then
  ./scripts/load_data.sh
fi;

# to be done: import POST route test (shall have a doc to index)
