#!/bin/bash
BadGuys=
TITLEcurl="%222017_week_$((`date +'%-U'` - 1))%22"
TITLE="2017_week_$((`date +'%-U'` - 1))"
URL="http://<CONFLUENCE_HOST>/rest/api/content/"
cd /tmp && rm -rf {badguy.txt,*.json}

ReportList=$(curl -s -n ${URL}search?cql=title=$TITLEcurl \
| python -mjson.tool | grep "self.*," | awk -F\" '{print $4}' \
| sed 's/<CONFLUENCE_HOST>/<CONFLUENCE_HOST>/')

content () {
curl -s -n $link?expand=body.storage
}

value () {
curl -s -n $link?expand=body.storage \
| python -mjson.tool | grep value | \
sed -e 's/<p><ac:structured-macro ac:name=\\"internal_project_report_name\\" ac:schema-version=\\"1\\" ac:macro-id=\\"[a-zA-Z0-9-]*\\" \/><\/p>//' \
-e 's/^[[:blank:]]*//' -e 's/^/{/' -e 's/\"$/\",/'
}

for link in $ReportList
do
if content | grep value | grep -q internal_project_report_name
then
badguy=$(/root/scripts/api.sh author ${link#$URL})
weburl=$(/root/scripts/api.sh webui ${link#$URL})
echo "$badguy http://<CONFLUENCE_HOST>$weburl <br>" >> badguy.txt
ver=$(/root/scripts/api.sh version ${link#$URL})
sp=$(curl -s -n $link?expand=body \
| python -mjson.tool | grep container \
| tr -dc '[:digit:][:upper:]\n')

echo -e "{\"id\":\"${link#$URL}\",\
\n\"type\":\"page\",\
\n\"title\":\"$TITLE\",\
\n\"space\":{\"key\":\"$sp\"},\
\n\"body\":\n{\"storage\":" > ${link#$URL}.json

value >> ${link#$URL}.json

echo -e "\"representation\":\"storage\"}},\n\
\"version\":{\"number\":$(expr $ver + 1)}}" >> ${link#$URL}.json

/root/scripts/api.sh post ${link#$URL}.json ${link#$URL}
fi
done

if [ -s badguy.txt ]; then
echo "<br>Above guys forgot to remove Internal_Project_Report_Name macro.<br>\
This have to be fixed before next week occurs.<br>\
This email probably means that above page(-s) were corrected automatically,<br>\
but without any guarantees." >> badguy.txt
mutt -e 'set content_type="text/html"' -s "Careless guys from Confluence" -- <ADMIN_EMAIL> < badguy.txt
fi
