#!/bin/sh
### DNS update locally (etc/host) - workaround for long ttl

if [ -z "${SCW_DNS_UPDATE_IP}" -o -z ${APP_HOST} ]; then
    exit 0;
fi;

cat /etc/hosts | grep -v ${APP_HOST} | awk -v ip=${SCW_DNS_UPDATE_IP} -v dns=${APP_HOST} '{print}END{print ip "\t" dns}' > /tmp/hosts
sudo cp /etc/hosts /etc/hosts.bak.$(date +%Y%m%d-%H%M)
sudo cp /tmp/hosts /etc/hosts

echo -e "\r\033[2K🔧  DNS - set ${SCW_DNS_UPDATE_IP} to ${APP_DNS_SHORT} in /etc/hosts to avoid ttl latency";
