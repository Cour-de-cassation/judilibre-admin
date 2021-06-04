#!/bin/bash
echo Test GET routes on ${APP_SCHEME}://${APP_HOST}:${APP_PORT}
for route in admin;do
  if curl -s -k --retry 5 --retry-delay 2 -XGET ${APP_SCHEME}://${APP_HOST}:${APP_PORT}/${route} | grep -q '"route":"GET /'${route}'"' ; then
      echo "✅ ${route}"
  else
      echo -e "\e[31m❌ ${route} !\e[0m"
      echo curl -k -XGET ${APP_SCHEME}://${APP_HOST}:${APP_PORT}/${route}
      curl -k -XGET ${APP_SCHEME}://${APP_HOST}:${APP_PORT}/${route}
      exit 1
  fi
done

# to be done: import POST route test (shall have a doc to index)
