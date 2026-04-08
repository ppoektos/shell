#!/bin/bash
cd /root/scripts
Count=0
RootPages="dsl d m to"
dChild="ip rs sdd hdd qcsd te tt pr"
mChild="ce sch cc fin mom psr ep ipr gate"
Gates="gateR gateD gateDV"
Url="http://<CONFLUENCE_HOST>/rest/api"
SpaceFile="/tmp/newSpace.json"
SpaceName="$1"
SpaceKey=$(echo $SpaceName \
        | sed -e 's/\(.\)[^ ]* */\1/g' -e 's/-//g' -e 's/ //g' \
        | tr [:lower:] [:upper:])

if [ -n "$2" ]; then SpaceDesc="$2"; else SpaceDesc="Develop sw and hw"; fi

spaceUnique () {
curl -s -n $Url/space/?spaceKey=$SpaceKey | python -mjson.tool | grep "size" | grep -o "[0-9]*"
}

echo -e "System got your request to create new space structure.\n\n\
        New space name will be:\n\
        \"$SpaceName\".\n\n\
        Generated space key will be: \"$SpaceKey\".\n\n\
        Check if above key is unique in Confluence:"

while [ "$(spaceUnique)" = "1" ] ; do
  echo "Not unique. Adding extra symbol to it."
  ((Count++))
  SpaceKey=${SpaceKey%[0-9]}$Count
done

echo -e "Unique.\nSpace key will be: \"$SpaceKey\".\n"

SpaceLink="http://<CONFLUENCE_HOST>/display/$SpaceKey"

echo -e "{\"key\":\"$SpaceKey\",\
        \n\"name\":\"$SpaceName\",\
        \n\"description\":{\"plain\":{\
        \n\"value\":\"$SpaceDesc\",\
        \n\"representation\":\"plain\"}}}" > $SpaceFile

SpaceId=$(curl -sn -X POST -H 'Content-Type: application/json' \
        -d @$SpaceFile $Url/space | python -mjson.tool \
        | grep "\"id\": \"[0-9]*\"," | grep -o "[0-9]*")

echo -e "Link to new space: $SpaceLink.\n\
        Or just go to http://<CONFLUENCE_HOST> to see updates in feed.\n\n\
        Id of new space home is \"$SpaceId\".\n\n\
        You have to grant permission for this space\n\
        and restict Project Management area.\n\
        You have to also assign label \"project\".\n\n\
        Creating root entries in space.."

for RootPage in $RootPages; do

    sed -i 's/"ancestors":[{"id":[0-9]*}],"space":{"key":"[0-9A-Z]*"},/"ancestors":[{"id":'$SpaceId'}],"space":{"key":"'$SpaceKey'"},/' $RootPage.json

    RootId=$(curl -sn -X POST -H 'Content-Type: application/json' \
            -d @/root/scripts/$RootPage.json $Url/content/ | python -mjson.tool \
            | grep children | head -1 | awk -F/ '{print $5}')

    echo "Id of $RootPage is $RootId."
    eval Root="$"${RootPage}Child

    if [ -n "$Root" ]; then
        echo "Creating child entries for root page.."

        for ChildPage in $Root; do
            sed -i 's/"ancestors":[{"id":[0-9]*}],"space":{"key":"[0-9A-Z]*"},/"ancestors":[{"id":'$RootId'}],"space":{"key":"'$SpaceKey'"},/' $ChildPage.json

            ChildId=$(curl -sn -X POST -H 'Content-Type: application/json' \
                    -d @/root/scripts/$ChildPage.json $Url/content/ | python -mjson.tool \
                    | grep children | head -1 | awk -F/ '{print $5}')

            if [ $ChildPage = "gate" ]; then
                echo "Creating child pages for Gates.."
                echo "Id of Gates page is $ChildId."

                for gate in $Gates; do
                    sed -i 's/"ancestors":[{"id":[0-9]*}],"space":{"key":"[0-9A-Z]*"},/"ancestors":[{"id":'$ChildId'}],"space":{"key":"'$SpaceKey'"},/' $gate.json

                    curl -sn -X POST -H 'Content-Type: application/json' \
                    -d @/root/scripts/$gate.json $Url/content/ > /dev/null 2>&1

                done
            fi
        done
    fi
done

echo "Job done."
