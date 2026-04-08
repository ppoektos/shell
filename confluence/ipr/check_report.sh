#!/bin/bash
Url="http://<CONFLUENCE_HOST>/rest/api/content"
ActiveProjects=<PAGE_ID_PROJECTS>
ActiveProjectsIds=$(/root/scripts/api.sh get $ActiveProjects \
| grep value | grep -oE '[0-9]{8}')

echo "List of projects without comfirmation from ${1}s:"

for ProjectId in $ActiveProjectsIds; do

SpaceId=$(curl -s -n $Url/search?cql=space.title~%22$ProjectId%22\&limit=1 \
| python -mjson.tool | grep space)
SpaceId=${SpaceId##*\/}
SpaceId=${SpaceId%\"*}
SpaceName=$(curl -s -n http://<CONFLUENCE_HOST>/rest/api/space/$SpaceId \
| python -mjson.tool | grep name | awk -F\" '{print $4}')
IprRoot=$(curl -s -n $Url?spaceKey=$SpaceId\&title=Internal%20Project%20Reporting \
| python -mjson.tool | grep id | awk -F\" '{print $4}')

if [ -z "$IprRoot" ]; then
  echo "IRP root hasn't been created for $ProjectId"
  continue
fi

LastReportName=$(curl -s -n $Url/$IprRoot/child/page?limit=60 \
| python -mjson.tool | grep -E 'title.*2017' | sort -V | tail -1)
LastReportId=$(curl -s -n $Url/$IprRoot/child/page?limit=60 \
| python -mjson.tool | grep -B 2 "$LastReportName" | grep id | awk -F\" '{print $4}')
Value=$(echo -e "`curl -s -n $Url/$LastReportId?expand=body.storage | python -mjson.tool \
| grep value`" | grep -B 1 "$1:" | head -1 )
Value=${Value#*>}
Value=${Value%<*}

if [ "$Value" = "incomplete" ]; then
  echo "Project id: $SpaceName"
fi
done
