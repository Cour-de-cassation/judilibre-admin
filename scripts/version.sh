#!/bin/sh

./scripts/check_install.sh > /dev/null

echo $(cat package.json | jq -r '.version')-$(export LC_COLLATE=C;export LC_ALL=C;cat tagfiles.version | xargs -I '{}' find {} -type f | egrep -v '(.tar.gz)$' | sort | xargs cat | sha256sum - | sed 's/\(......\).*/\1/')
