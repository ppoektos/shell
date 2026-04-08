#!/bin/bash
URL="http://<CONFLUENCE_HOST>/rest/api/content"

case $1 in
  post)
      curl -sS -n -X PUT -H 'Content-Type: application/json' \
      -d @/tmp/$2 $URL/$3 > /dev/null 2>&1
      ;;
  version)
      curl -s -n $URL/$2?expand=version \
      | python -mjson.tool | grep number | tr -cd '[:digit:]\n'
      ;;
  author)
      curl -s -n $URL/$2?expand=version \
      | python -mjson.tool | grep username | awk -F\" '{print $4}'
      ;;
  webui)
      curl -s -n $URL/$2?expand=version \
      | python -mjson.tool | grep webui | awk -F\" '{print $4}'
      ;;
  get)
      curl -s -n $URL/$2?expand=body.storage \
      | python -mjson.tool
      ;;
  space)
      curl -s -n $URL/<PAGE_ID>?expand=body.storage \
      | python -mjson.tool
      ;;
  delete)
      curl -sS -n -X DELETE \
      $URL/<PAGE_ID> | python -mjson.tool
      ;;
  custom)
      curl -s -n $URL/<PAGE_ID>/history/5/macro/id/<MACRO_ID>?expand=body,history \
      | python -mjson.tool
      ;;
  child)
      curl -sS -n -X POST -H 'Content-Type: application/json' \
      -d @/tmp/child.json $URL | python -mjson.tool
      ;;
  *)
      echo "`basename $0`: use either post or get as parameter."
      exit 1
      ;;
esac
