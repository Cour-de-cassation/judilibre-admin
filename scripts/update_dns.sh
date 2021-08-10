#!/bin/sh
### DNS update

: ${SCW_DNS_API:="https://api.scaleway.com/domain/v2beta1/dns-zones"}

if [ -z "${SCW_DNS_UPDATE_IP}" -o -z ${SCW_DNS_SECRET_TOKEN} ]; then
    exit 0;
fi;

if [ -z "${APP_HOST}" ]; then
    echo -e "\e[31m❌  DNS - APP_HOST has to be set to update DNS" && exit 1;
fi

SCW_DNS_ZONE=$(curl -s "${SCW_DNS_API}" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}"  | jq -r '.dns_zones[0].domain')

if [ -z "${SCW_DNS_ZONE}" ];then
    echo -e "\e[31m❌  DNS - failed to get dns zone" && exit 1;
fi

APP_DNS_SHORT=$(echo ${APP_HOST} | sed "s/.${SCW_DNS_ZONE}//")

SCW_DNS_RECORD_IP=$(curl -s "${SCW_DNS_API}/${SCW_DNS_ZONE}/records" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}"  | jq -cr '.records[] | select( .name == "'${APP_DNS_SHORT}'") | .data')

if [ ! -z "${SCW_DNS_RECORD_IP}" ];then
    if [ "${SCW_DNS_RECORD_IP}" != "${SCW_DNS_UPDATE_IP}" ]; then
        SCW_DNS_RECORD_ID=$(curl -s "${SCW_DNS_API}/${SCW_DNS_ZONE}/records" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}"  | jq -cr '.records[] | select( .name == "'${APP_DNS_SHORT}'") | .id');
        SCW_DNS_DELETE_RECORD="{'changes':[{'delete':{'id':'${SCW_DNS_RECORD_ID}'}}]}";
        SCW_DNS_DELETE_RECORD=$(echo $SCW_DNS_DELETE_RECORD | tr "'" '"' );
        if (curl -s -XPATCH "${SCW_DNS_API}/${SCW_DNS_ZONE}/records" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}" -d ${SCW_DNS_DELETE_RECORD} | grep -q records);then
            echo "✓   DNS - deleted previous record for ${APP_DNS_SHORT}";
        else
            echo "\e[31m❌  DNS - failed deleting previous record for ${APP_DNS_SHORT}" && exit 1;
        fi;
    else
        echo "✓   DNS - record ${APP_DNS_SHORT} already exists";
        SKIP=true
    fi;
fi

if [ -z "${SKIP}" ]; then
    SCW_DNS_RECORD="{'changes':[{'add':{
                        'records': [{
                            'ttl': 60,
                            'type':'A','name':'${APP_DNS_SHORT}','data':'${SCW_DNS_UPDATE_IP}'
                            }]
                        }}]}"

    SCW_DNS_RECORD=$(echo $SCW_DNS_RECORD | tr "'" '"' | jq -c '.')

    if (curl -s -XPATCH "${SCW_DNS_API}/${SCW_DNS_ZONE}/records" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}" -d ${SCW_DNS_RECORD} | grep -q ${APP_DNS_SHORT});then
        echo "🚀  DNS - set ${SCW_DNS_UPDATE_IP} to ${APP_DNS_SHORT}";
    else
        echo "\e[31m❌  DNS - set ${SCW_DNS_UPDATE_IP} to ${APP_DNS_SHORT} !" && exit 1;
    fi
fi