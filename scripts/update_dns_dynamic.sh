#!/bin/sh
### DNS update

: ${SCW_DNS_API:="https://api.scaleway.com/domain/v2beta1/dns-zones"}

if [ -z "${DYNAMIC_DNS}" -o -z "${DYNAMIC_DNS_IP}" -o -z "${DYNAMIC_DNS_IP_ALTER}" -o -z "${DYNAMIC_DNS_URL}" -o -z "${DYNAMIC_DNS_TEST}" -o -z "${SCW_DNS_SECRET_TOKEN}" ]; then
    exit 0;
fi;

export SCW_DNS_ZONE=$(echo ${APP_HOST} | sed 's/.*\.\([^\.]*\.[^\.]*$\)/\1/')

if [ "${SCW_DNS_ZONE}" != "$(curl -s "${SCW_DNS_API}" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}" | jq -r '.dns_zones[] | select (.domain == "'${SCW_DNS_ZONE}'") | .domain')" ];then
    echo -e "\e[31m❌  DNS - failed to get dns zone" && exit 1;
fi

APP_DNS_SHORT=$(echo ${DYNAMIC_DNS} | sed "s/.${SCW_DNS_ZONE}//")

SCW_DNS_RECORD_IP=$(curl -s "${SCW_DNS_API}/${SCW_DNS_ZONE}/records" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}"  | jq -cr '.records[] | select( .name == "'${APP_DNS_SHORT}'") | .data')

if [ ! -z "${SCW_DNS_RECORD_IP}" ];then
    SCW_DNS_RECORD_ID=$(curl -s "${SCW_DNS_API}/${SCW_DNS_ZONE}/records" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}"  | jq -cr '.records[] | select( .name == "'${APP_DNS_SHORT}'") | .id');
    SCW_DNS_DELETE_RECORD="{'changes':[{'delete':{'id':'${SCW_DNS_RECORD_ID}'}}]}";
    SCW_DNS_DELETE_RECORD=$(echo $SCW_DNS_DELETE_RECORD | tr "'" '"' );
    if (curl -s -XPATCH "${SCW_DNS_API}/${SCW_DNS_ZONE}/records" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}" -d ${SCW_DNS_DELETE_RECORD} | grep -q records);then
        echo "✓   DNS - deleted previous record for ${APP_DNS_SHORT}";
    else
        echo "\e[31m❌  DNS - failed deleting previous record for ${APP_DNS_SHORT}" && exit 1;
    fi;
fi



SCW_DNS_RECORD="{'changes':[{'add':{
                    'records': [{
                        'ttl': 60,
                        'type':'A',
                        'name':'${APP_DNS_SHORT}','data':'${DYNAMIC_DNS_IP_ALTER}',
                        'http_service_config':{
                            'ips':['${DYNAMIC_DNS_IP}'],
                            'must_contain':'${DYNAMIC_DNS_TEST}',
                            'url':'${DYNAMIC_DNS_URL}'
                            }
                        }]
                    }}]}"

SCW_DNS_RECORD=$(echo $SCW_DNS_RECORD | tr "'" '"' | jq -c '.')

if (curl -s -XPATCH "${SCW_DNS_API}/${SCW_DNS_ZONE}/records" -H "X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}" -d ${SCW_DNS_RECORD} | grep -q ${APP_DNS_SHORT});then
    # echo curl -s -XPATCH "'${SCW_DNS_API}/${SCW_DNS_ZONE}/records'" -H "'X-Auth-Token: ${SCW_DNS_SECRET_TOKEN}'" -d "'${SCW_DNS_RECORD}'"
    echo "🚀  DNS - set ${DYNAMIC_DNS_IP}/${DYNAMIC_DNS_IP_ALTER} to ${APP_DNS_SHORT}";
else
    echo "\e[31m❌  DNS - set ${DYNAMIC_DNS_IP}/${DYNAMIC_DNS_IP_ALTER} to ${APP_DNS_SHORT} !" && exit 1;
fi
