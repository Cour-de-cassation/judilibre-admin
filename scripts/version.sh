#!/bin/sh

cat tagfiles.version | xargs -I '{}' find {} -type f | egrep -v '(.tar.gz)$' | sort | xargs cat | sha256sum - | sed 's/\(......\).*/\1/'
