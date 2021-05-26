#!/bin/bash
echo Test GET routes on ${API_SCHEME}://${API_HOST}:${API_PORT}
for route in admin;do
  if curl -s --retry 5 --retry-delay 2 -XGET ${SCHEME}://${HOST}:${API_PORT}/${route} | grep -q '"route":"GET /'${route}'"' ; then
      echo "✅ ${route}"
  else
      echo -e "\e[31m❌ ${route} !\e[0m"
      echo curl -XGET ${API_SCHEME}://${API_HOST}:${API_PORT}/${route}
      curl -XGET ${API_SCHEME}://${API_HOST}:${API_PORT}/${route}
      exit 1
  fi
done

# to be done: import POST route test (shall have a doc to index)
