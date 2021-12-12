#!/bin/bash

./scripts/check_install.sh
export CURL="curl -s --retry 5 --retry-delay 2 --max-time 5"

if [ ! -z "${APP_SELF_SIGNED}" ];then
  export CURL="${CURL} -k"
fi;

if [ "${ACME}" == "acme-staging" ];then
  curl -s https://letsencrypt.org/certs/staging/letsencrypt-stg-root-x1.pem -o letsencrypt-stg-root-x1.pem
  export CURL="${CURL} --cacert letsencrypt-stg-root-x1.pem"
fi;

for route in "admin?command=test";do
  if ${CURL} "${APP_SCHEME}://admin:${HTTP_PASSWD}@${APP_HOST}:${APP_PORT}/${route}" | grep -q 'disponible' ; then
    echo "✅  test api ${APP_HOST}/${route} ";
  else
    if (${CURL} -k "${APP_SCHEME}://admin:${HTTP_PASSWD}@${APP_HOST}:${APP_PORT}/${route}" | grep -q 'disponible' );then
      echo -e "\e[33m⚠️   test api ${APP_HOST}/${route} (invalid SSL cert)\e[0m";
    else
      echo -e "\e[31m❌ test ${APP_HOST}/${route} !\e[0m";
      echo ${CURL} ${APP_SCHEME}://admin:${HTTP_PASSWD}@${APP_HOST}:${APP_PORT}/${route};
      $(echo ${CURL} | sed 's/ \-s / /') ${APP_SCHEME}://admin:${HTTP_PASSWD}@${APP_HOST}:${APP_PORT}/${route};
      exit 1;
    fi;
  fi;
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
