#!/bin/bash

export OS_TYPE=$(cat /etc/os-release | grep -E '^NAME=' | sed 's/^.*debian.*$/DEB/I;s/^.*ubuntu.*$/DEB/I;s/^.*fedora.*$/RPM/I;s/.*centos.*$/RPM/I;')

if ! (which envsubst > /dev/null 2>&1); then
        if [ "${OS_TYPE}" = "DEB" ]; then
                apt-get install -yqq gettext;
        fi;
        if [ "${OS_TYPE}" = "RPM" ]; then
                sudo yum install -y gettext;
        fi;
fi;

if ! (which jq > /dev/null 2>&1); then
        if [ "${OS_TYPE}" = "DEB" ]; then
                apt-get install -yqq jq;
        fi;
        if [ "${OS_TYPE}" = "RPM" ]; then
                sudo yum install -y jq;
        fi;
fi
