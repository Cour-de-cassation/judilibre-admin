#!/bin/bash

export OS_TYPE=$(cat /etc/os-release | grep -E '^NAME=' | sed 's/^.*debian.*$/DEB/I;s/^.*ubuntu.*$/DEB/I;s/^.*fedora.*$/RPM/I;s/.*centos.*$/RPM/I;')

if ! (which envsubst > /dev/null 2>&1); then
        if [ "${OS_TYPE}" = "DEB" ]; then
                sudo apt-get install -yqq gettext;
        fi;
        if [ "${OS_TYPE}" = "RPM" ]; then
                sudo yum install -y gettext;
        fi;
fi;

if ! (which jq > /dev/null 2>&1); then
        if [ "${OS_TYPE}" = "DEB" ]; then
                sudo apt-get install -yqq jq;
        fi;
        if [ "${OS_TYPE}" = "RPM" ]; then
                sudo yum install -y jq;
        fi;
fi

if ! (which htpasswd > /dev/null 2>&1); then
        if [ "${OS_TYPE}" = "DEB" ]; then
                sudo apt-get install -yqq apache2-utils;
        fi;
        if [ "${OS_TYPE}" = "RPM" ]; then
                sudo yum install -y httpd-tools;
        fi;
fi


if ! (which rclone > /dev/null 2>&1); then
        if [ "${OS_TYPE}" = "DEB" ]; then\
                curl -s -O https://downloads.rclone.org/rclone-current-linux-amd64.deb;\
                sudo dpkg -i rclone-current-linux-amd64.deb; \
                rm rclone-*-linux-amd64*;\
        fi;\
        if [ "${OS_TYPE}" = "RPM" ]; then\
                curl -s -O https://downloads.rclone.org/rclone-current-linux-amd64.rpm;\
                sudo yum localinstall -y rclone-current-linux-amd64.rpm; \
                rm rclone-*-linux-amd64*;\
        fi;\
fi;
