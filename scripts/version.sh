#!/bin/sh

./scripts/check_install.sh > /dev/null 2>&1

echo $(cat package.json | jq -r '.version')-$(cat tagfiles.version | xargs -I '{}' find {} -type f | egrep -v '(.tar.gz)$' | sort | xargs cat | sha256sum - | sed 's/\(......\).*/\1/')
