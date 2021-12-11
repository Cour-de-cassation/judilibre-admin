#!/bin/sh
set -e

if [ ! -f server.crt -o ! -f server.key ];then
    if [ -z "${APP_HOST}" ];then
        echo "\e[31m❌  APP_HOST must be in env\e[0m" && exit 1;
    fi;
    echo "▶️   Self-signed cert generation"
    (
        if ! (which openssl > /dev/null 2>&1);then
            (which apk 2>&1) && apk add openssl
            (which apt 2>&1) && apt install openssl
        fi;
        export PASS=$(openssl rand -base64 32)
        openssl genrsa -des3 -passout pass:${PASS} -out server.pass.key 4096
        openssl rsa -passin pass:${PASS} -in server.pass.key -out server.key
        rm server.pass.key
        APP_OU=$(echo ${APP_HOST} | sed 's/[^\.]*.//')
        openssl req -new -key server.key -out server.csr -subj "/C=FR/ST=Paris/L=Paris/O=cour-de-cassation.justice.fr/OU=${APP_OU}/CN=${APP_HOST}/subjectAltName=${APP_ID}-svc.${KUBE_NAMESPACE}.svc.cluster.local"
        openssl x509 -req -sha256 -days 365 -in server.csr -signkey server.key -out server.crt
    ) 2>&1 | awk '{print "    " $0}'
    echo "✓   Self-signed cert generated"
fi;

