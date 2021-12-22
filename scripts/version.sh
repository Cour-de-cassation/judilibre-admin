#!/bin/sh

./scripts/check_install.sh > /dev/null

echo $( ( [ -f "package.json" ] && (cat package.json | jq -r '.version') ) || ( [ -f "setup.py" ] && ( grep -r __version__ */__init__.py | sed 's/.*=//;s/"//g;s/\s//g' ) ) || (git tag | tail -1) )-$(export LC_COLLATE=C;export LC_ALL=C;cat tagfiles.version | xargs -I '{}' find {} -type f | egrep -v '(.tar.gz)$' | sort | xargs cat | sha256sum - | sed 's/\(......\).*/\1/')
