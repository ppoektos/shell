#!/bin/bash
rm -f /tmp/child-*.json
Url="http://<CONFLUENCE_HOST>/rest/api/content"
Title="$(date +'%Y')_week_$(date +'%-V')"
ActiveProjects=<PAGE_ID_PROJECTS>
ActiveProjectsIds=$(/root/scripts/api.sh get $ActiveProjects \
                    | grep value | grep -oE '[0-9]{8}')

if [ $(date +'%-W') -eq 1 ]; then
    Move=true
    PastYear=$(date +%Y --date="last year")
    Year=$PastYear
    else
    Move=
    Year=$(date +%Y)
fi

MoveToPastYear () {

    PastIPRRoot=$(curl -s -n $Url?spaceKey=$SpaceId\&title=$PastYear \
                | python -mjson.tool | grep id | awk -F\" '{print $4}')

    if [ -z $PastIPRRoot ]; then

        echo "PastYear $PastYear page isn't created. Create it now.."

        PastIPRRoot=$(curl -sn -X POST -H 'Content-Type: application/json' \
                    -d'{"type":"page","title":"'$PastYear'",
                    "ancestors":[{"id":'$IprRoot'}], "space":{"key":"'$SpaceId'"},
                    "body":{"storage":{"value": "<p>Old reports are saved here.</p>",
                    "representation":"storage"}}}' $Url | python -mjson.tool \
                    | grep children | head -1 | awk -F/ '{print $5}')

        elif curl -s -n $Url/$PastIPRRoot?expand=ancestors | python -mjson.tool | grep -qE "\"id\": \"$IprRoot\","; then

        echo "$PastYear page is under IPR root."

        else

        echo "$PastYear page is not under IPR root!!"

    fi

    echo "Move past reports to $PastYear root page.."

    arr=($(curl -s -n $Url/$IprRoot/child/page?limit=600 | python -mjson.tool \
        | grep -E "title.*${PastYear}_" | awk -F"\"" '{print $4}' | sort -V))

    for i in ${arr[@]}; do
        echo "Get ID of $i page.."
        PastReportPageId=$(curl -s -n $Url?spaceKey=$SpaceId\&title=$i | python -mjson.tool | grep id | awk -F\" '{print $4}')
        echo "ID is $PastReportPageId."
        echo "Move it.."
        curl -sn -X GET 'http://<CONFLUENCE_HOST>/pages/movepage.action?pageId='$PastReportPageId'&spaceKey='$SpaceId'&targetTitle='$PastYear'&position=append' \
        -H 'x-atlassian-token: no-check' | python -mjson.tool
    done

    unset arr
}

CreateInitialReport () {

sed -i 's/"title":"201[8-9]_week_[0-9]*","ancestors":[{"id":[0-9]*}],"space":{"key":"[0-9A-Z]*"},/"title":"'$Title'","ancestors":[{"id":'$IprRoot'}],"space":{"key":"'$SpaceId'"},/' /root/scripts/iprr.json

InitialReportId=$(curl -sS -n -X POST -H 'Content-Type: application/json' \
                -d @/root/scripts/iprr.json $Url | python -mjson.tool \
                | grep children | head -1 | awk -F/ '{print $5}')

echo "InitialReportId: $InitialReportId"

curl -sn -X POST -H 'Content-Type: application/json' \
-d'{"prefix":"global","name":"newipr"}' \
$Url/$InitialReportId/label  | python -mjson.tool > /dev/null 2>&1

echo
}

for ProjectId in $ActiveProjectsIds; do

    echo "Project id: $ProjectId"

    SpaceId=$(curl -s -n $Url/search?cql=space.title~%22$ProjectId%22\&limit=1 \
            | python -mjson.tool | grep space)

    SpaceId=${SpaceId##*\/}
    SpaceId=${SpaceId%\"*}

    echo "Space id: $SpaceId"

    SpaceName=$(curl -s -n http://<CONFLUENCE_HOST>/rest/api/space/$SpaceId \
                | python -mjson.tool | grep name | awk -F\" '{print $4}')

    echo "Space name: $SpaceName"

    IprRoot=$(curl -s -n $Url?spaceKey=$SpaceId\&title=Internal%20Project%20Reporting \
                | python -mjson.tool | grep id | awk -F\" '{print $4}')

    echo "IPR root id: $IprRoot"

    NumberOfChild=$(curl -s -n $Url/$IprRoot/child/page \
                | python -mjson.tool | grep size | grep -o '[0-9]*')

    if [ -z "$IprRoot" ]; then
        echo "IRP root hasn't been created for $ProjectId"
        continue
    fi

    if [ $NumberOfChild -eq 0 ]; then
        echo "IPR root has no child. Need to create report."
        CreateInitialReport
        continue
    fi

    IsChildAReport=$(curl -s -n $Url/$IprRoot/child/page?limit=600 \
                    | python -mjson.tool | grep -E "title.*${Year}_")

    if [ $NumberOfChild -gt 0 ] && [ ! $IsChildAReport ]; then
        echo "IPR root has no child reports. Need to create one."
        CreateInitialReport
        continue
    fi

LastReportName=$(curl -s -n $Url/$IprRoot/child/page?limit=600 \
                | python -mjson.tool | grep -E "title.*${Year}_" | sort -V | tail -1)

echo "Last report name: $LastReportName"

LastReportId=$(curl -s -n $Url/$IprRoot/child/page?limit=60 \
                | python -mjson.tool | grep -B 2 "$LastReportName" | grep id | awk -F\" '{print $4}')

echo "Last report id: $LastReportId"

Value=$(curl -s -n $Url/$LastReportId?expand=body.storage \
        | python -mjson.tool | grep value \
        | sed -e 's/^[[:blank:]]*//' -e 's/^/{/' -e 's/\"$/\",/' -e 's/>complete/>incomplete/g' \
        -e 's/<p>PM: <ac:link><ri:user ri:userkey=\\"[a-z0-9]*\\" \/><\/ac:link>/<p>PM: /' \
        -e 's/<p>TL: <ac:link><ri:user ri:userkey=\\"[a-z0-9]*\\" \/><\/ac:link>/<p>TL: /' \
        -e 's/\(.*\)<tr>.*<p><strong>Main challenges by PM:<\/strong>.*<\/td>/\1<tr><td colspan=\\"9\\"><p><strong>Main challenges by PM:<\/strong> <ac:placeholder>Write 1-3 hot issues that you are dealing with now. E.g. do you experience any blockers?<\/ac:placeholder><\/p><p><strong>Main challenges by TL:<\/strong> <ac:placeholder>Write 1-3 hot issues that you are dealing with now. E.g. do you experience any blockers?<\/ac:placeholder><\/p><\/td>/' \
        -e 's/<p>&nbsp;<\/p>//g' \
        -e 's/<\/table>.*<\/ac:rich/<\/table><\/ac:rich/')

echo -e "{\"type\":\"page\",\
\n\"title\":\"$Title\",\
\n\"ancestors\":[{\"id\":$IprRoot}],\
\n\"space\":{\"key\":\"$SpaceId\"},\
\n\"body\":\n{\"storage\":" > /tmp/child-$LastReportId.json

echo "$Value" >> /tmp/child-$LastReportId.json

echo -e "\"representation\":\"storage\"}}}" >> /tmp/child-$LastReportId.json

NewReportId=$(curl -sS -n -X POST -H 'Content-Type: application/json' \
-d @/tmp/child-$LastReportId.json $Url | python -mjson.tool \
| grep children | head -1 | awk -F/ '{print $5}')

echo "NewReportId: $NewReportId"

curl -sn -X POST -H 'Content-Type: application/json' \
-d'{"prefix":"global","name":"newipr"}' \
$Url/$NewReportId/label  | python -mjson.tool > /dev/null 2>&1

if [ $Move ]; then MoveToPastYear; fi

echo; sleep 30
done
