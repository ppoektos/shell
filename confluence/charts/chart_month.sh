#!/bin/bash
cd /root/scripts || exit 1
Url="http://<CONFLUENCE_HOST>/rest/api/content"
Month=$(date +'%-m' -d 'last month')
ActiveProjectsIds=$(./api.sh get <PAGE_ID_PROJECTS> \
| grep -oE '[0-9]{8} - [a-zA-Z0-9 ]*')
Version=$(./api.sh version <PAGE_ID>)
((Version++))
Table=

cat > /tmp/chartmonth1 <<DOCHERE
{"id":"<PAGE_ID>",
"type":"page",
"title":"Projects vs Spent monthly chart",
"space":{"key":"<SPACE_KEY>"},
"body":
{"storage":
{"value":
"<p class=\"auto-cursor-target\"><br /></p>
<ac:structured-macro ac:name=\"chart\" ac:schema-version=\"1\" ac:macro-id=\"6ff2053d-905e-4058-a969-f57bdb17f8d3\">
<ac:parameter ac:name=\"imageFormat\">png</ac:parameter>
<ac:parameter ac:name=\"width\">1024</ac:parameter>
<ac:parameter ac:name=\"dataOrientation\">vertical</ac:parameter>
<ac:parameter ac:name=\"title\">Month $Month</ac:parameter>
<ac:parameter ac:name=\"height\">600</ac:parameter>
<ac:rich-text-body>
<p class=\"auto-cursor-target\"><br /></p>
<table class=\"wrapped relative-table\" style=\"width: 22.6546%;\"><colgroup><col style=\"width: 76.3333%;\" /><col style=\"width: 23.6667%;\" /></colgroup>
<tbody>
<tr>
<th>Project</th>
<th>Hours</th></tr>
DOCHERE

while read -r Project; do
    Id=${Project:0:8}
    lenght=${#Project}
    name=${Project:11:$lenght}

    parent=$(mysql --login-path=<DB_NAME> -Nse \
            "use <DB_NAME>; SELECT id FROM projects WHERE name LIKE '%$Id%' \
            AND projects.parent_id is NULL;")

    arr=(`mysql --login-path=<DB_NAME> -Nse \
        "use <DB_NAME>; SELECT id FROM projects WHERE parent_id = '$parent'"`)

    arr+=($parent)

    sum=0
    for f in ${arr[@]}; do
        s=$(mysql --login-path=<DB_NAME> -Nse \
        "use <DB_NAME>; SELECT SUM(ROUND(time_entries.hours, 2)) \
        FROM time_entries WHERE project_id = '$f' \
        AND YEAR(time_entries.spent_on) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) \
        AND MONTH(time_entries.spent_on) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH);")

        [[ "$s" != "NULL" ]] && sum=$(echo "$sum $s" | awk '{print $1 + $2}')
    done

    Table="$Table\n<tr><td colspan=\\\"1\\\">$name</td><td colspan=\\\"1\\\">$sum</td></tr>"

done <<< "$ActiveProjectsIds"

echo -e "$Table\n</tbody></table>\n<p class=\\\"auto-cursor-target\\\">\
<br /></p></ac:rich-text-body></ac:structured-macro>\",\n\
\"representation\":\"storage\"}},\n\"version\":{\"number\":$Version}}" > /tmp/chartmonth2

cat /tmp/{chartmonth1,chartmonth2} > /tmp/chartmonth.json
./api.sh post chartmonth.json <PAGE_ID>
