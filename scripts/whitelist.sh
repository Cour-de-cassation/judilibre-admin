#!/bin/bash
(
    echo 62.210.0.0/16 #scw-dns
    curl -s https://api.github.com/meta | jq -r '.actions[]' | grep -v '::' | tr '\n' ',' #github-actions
    curl -s https://uptimerobot.com/inc/files/ips/IPv4andIPv6.txt | grep -v '::' | tr '\n' ',' #uptime-robot
    echo 185.24.185.46/27 #piste
    echo 185.24.186.214 #mj
    echo 78.192.252.15,163.172.185.238 #fa
    echo -n 80.87.224.00/22 #actimage
) | tr '\n' ','