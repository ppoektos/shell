#!/bin/bash
cd /root/scripts
Types="nominal registered invoiced noninvoiced sales meeting ill holiday"
Url="http://<CONFLUENCE_HOST>/rest/api/content"
NewPage=0
PERoot=<PAGE_ID>
Year=$(date +%Y)
Month=$(date +%-m)

case $Month in
    1) Year=$(date +%Y -d 'last year')
    ;;
    2) NewPage=1
    ;;
esac

Title="Charts_$Year"

if [ $NewPage = 1 ]; then

    curl -sn -X PUT -H 'Content-Type: application/json' \
-d'{"type":"page","title":"'$Title'",
"ancestors":[{"id":'$PERoot'}], "space":{"key":"<SPACE_KEY>"},
"body":{"storage":{"value":"<p>Page</p>","representation":"storage"}}}' \
$Url/ | python -mjson.tool

fi

PageId=$(curl -s -n $Url?spaceKey=<SPACE_KEY>\&title=$Title \
        | python -mjson.tool | grep id | awk -F\" '{print $4}')

Version=$(./api.sh version $PageId)
((Version++))

func_rename () {
case $1 in
    prod) Cell=Productivity
    ;;
    eff) Cell=Efficiency
    ;;
    pe) Cell=PE
    ;;
    nominal) Cell="Nominal working"
    ;;
    registered) Cell="Total registered"
    ;;
    invoiced) Cell=Billable
    ;;
    noninvoiced) Cell="Non-billable"
    ;;
    sales) Cell=Sales
    ;;
    meeting) Cell=Meetings
    ;;
    ill) Cell=Ill
    ;;
    holiday) Cell=Holidays
    ;;
    *) Cell="$1"
    ;;
esac
}


cat > /tmp/chartpe.json <<DOCHERE
{"id":"$PageId",
"type":"page",
"title":"$Title",
"space":{"key":"<SPACE_KEY>"},
"body":
{"storage":
{"value":
"<p class=\"auto-cursor-target\"><br/></p>
<p>This page is auto-generated.</p><br></br>
<ac:structured-macro ac:macro-id=\"2c5d7875-08d4-4cf7-92cd-e3fae3a6d68d\" ac:name=\"expand\" ac:schema-version=\"1\">
  <ac:parameter ac:name=\"title\">Legend</ac:parameter>
  <ac:rich-text-body>
    <p class=\"auto-cursor-target\">
      <br/>
    </p>
    <table>
      <colgroup>
        <col/>
        <col/>
        <col/>
      </colgroup>
      <tbody>
        <tr>
          <td class=\"highlight-grey\" data-highlight-colour=\"grey\" style=\"text-align: center;\">
            <strong>Teams</strong>
          </td>
          <td colspan=\"2\">
            <br/>
          </td>
        </tr>
        <tr>
          <td rowspan=\"5\" style=\"text-align: center;\">
            <br/>
          </td>
          <td class=\"highlight-grey\" colspan=\"1\" data-highlight-colour=\"grey\" style=\"text-align: center;\">
            <strong>office1</strong>
          </td>
          <td><office1_members></td>
        </tr>
        <tr>
          <td class=\"highlight-grey\" colspan=\"1\" data-highlight-colour=\"grey\" style=\"text-align: center;\">
            <strong>office2</strong>
          </td>
          <td><office2_members></td>
        </tr>
        <tr>
          <td class=\"highlight-grey\" colspan=\"1\" data-highlight-colour=\"grey\" style=\"text-align: center;\">
            <strong>office3</strong>
          </td>
          <td><office3_members></td>
        </tr>
        <tr>
          <td class=\"highlight-grey\" colspan=\"1\" data-highlight-colour=\"grey\" style=\"text-align: center;\">
            <strong>office4</strong>
          </td>
          <td colspan=\"1\"><office4_members></td>
        </tr>
        <tr>
          <td class=\"highlight-grey\" colspan=\"1\" data-highlight-colour=\"grey\" style=\"text-align: center;\">
            <strong>ADMIN</strong>
          </td>
          <td colspan=\"1\"><admin_members></td>
        </tr>
        <tr>
          <td class=\"highlight-grey\" colspan=\"1\" data-highlight-colour=\"grey\" style=\"text-align: center;\">
            <strong>Departments</strong>
          </td>
          <td colspan=\"2\">
            <br/>
          </td>
        </tr>
        <tr>
          <td rowspan=\"3\">
            <br/>
          </td>
          <td class=\"highlight-grey\" colspan=\"1\" data-highlight-colour=\"grey\" style=\"text-align: center;\">
            <strong>SWDE</strong>
          </td>
          <td colspan=\"1\"><swde_members></td>
        </tr>
        <tr>
          <td class=\"highlight-grey\" colspan=\"1\" data-highlight-colour=\"grey\" style=\"text-align: center;\">
            <strong>HWDE</strong>
          </td>
          <td colspan=\"1\"><hwde_members></td>
        </tr>
        <tr>
          <td class=\"highlight-grey\" colspan=\"1\" data-highlight-colour=\"grey\" style=\"text-align: center;\">
            <strong>QCDE</strong>
          </td>
          <td colspan=\"1\"><qcde_members></td>
        </tr>
        <tr>
          <td class=\"highlight-grey\" colspan=\"2\" data-highlight-colour=\"grey\" style=\"text-align: center;\">
            <strong>TLs</strong>
          </td>
          <td colspan=\"1\"><tl_members></td>
        </tr>
      </tbody>
    </table>
    <p class=\"auto-cursor-target\">
      <br/>
    </p>
  </ac:rich-text-body>
</ac:structured-macro>
<p>
  <br/>
</p>
DOCHERE

for units in depts teams users; do
    units_details=$(echo "${units%?}")
    units_list=$(mysql --login-path=<DB_NAME> -Nse "use effort; SELECT DISTINCT $units_details FROM $units ORDER BY $units_details;")

cat >> /tmp/chartpe.json <<DOCHERE
<ac:structured-macro ac:macro-id=\"73b7f9a6-0eae-4e3f-9f77-31837f8356c8\" ac:name=\"expand\" ac:schema-version=\"1\">
<ac:parameter ac:name=\"title\">$units</ac:parameter>
<ac:rich-text-body>
<p class=\"auto-cursor-target\">
<br/>
</p>
DOCHERE

    for department in $units_list; do

cat >> /tmp/chartpe.json <<DOCHERE
<ac:structured-macro ac:macro-id=\"0b097072-023b-434b-9407-d4682fd935c2\" ac:name=\"chart\" ac:schema-version=\"1\">
<ac:parameter ac:name=\"width\">500</ac:parameter>
<ac:parameter ac:name=\"title\">$department</ac:parameter>
<ac:parameter ac:name=\"type\">line</ac:parameter>
<ac:parameter ac:name=\"rangeAxisUpperBound\">120</ac:parameter>
<ac:rich-text-body>
<p class=\"auto-cursor-target\">
<br/>
</p>
<table class=\"wrapped\">
<tbody>
<tr>
<td><br/></td>
DOCHERE

        while read month; do
            echo "<td>$month</td>" >> /tmp/chartpe.json
        done < <(mysql --login-path=<DB_NAME> -Nse \
                "use effort; SELECT monthname(date) FROM $units \
                WHERE $units_details = '$department' AND year(date) = '$Year' \
                ORDER BY month(date);")

        for f in prod eff pe; do
            func_rename $f
            echo -e "</tr>\n<tr>\n<td>$Cell</td>" >> /tmp/chartpe.json

            while read i; do
                echo "<td>$i</td>" >> /tmp/chartpe.json
            done < <(mysql --login-path=<DB_NAME> -Nse \
                    "use effort; SELECT $f FROM $units \
                    WHERE $units_details = '$department' AND year(date) = '$Year' \
                    ORDER BY id;")
        done

cat >> /tmp/chartpe.json <<DOCHERE
</tr>
</tbody></table>
</ac:rich-text-body>
</ac:structured-macro>
<p><br/></p>
DOCHERE

cat >> /tmp/chartpe.json <<DOCHERE
<table class=\"wrapped\">
<tbody>
<tr>
<th style=\"text-align: center;\">$(echo $department | tr [:lower:] [:upper:]) hours</th>
DOCHERE

            while read month; do
                echo "<th>$month</th>" >> /tmp/chartpe.json
            done < <(mysql --login-path=<DB_NAME> -Nse \
                    "use effort; SELECT monthname(date) FROM $units \
                    WHERE $units_details = '$department' AND year(date) = '$Year' \
                    ORDER BY month(date);")

            for f in $Types; do
                func_rename $f
                echo -e "</tr>\n<tr>\n<th>$Cell</th>" >> /tmp/chartpe.json

                while read i; do
                    echo "<td style=\\\"text-align: center;\\\">$i</td>" >> /tmp/chartpe.json
                done < <(mysql --login-path=<DB_NAME> -Nse \
                        "use effort; SELECT $f FROM $units \
                        WHERE $units_details = '$department' AND year(date) = '$Year' \
                        ORDER BY id;")
            done

cat >> /tmp/chartpe.json <<DOCHERE
</tr>
</tbody></table>
<p><br/></p>
DOCHERE

    done

cat >> /tmp/chartpe.json <<DOCHERE
<p class=\"auto-cursor-target\">
<br/>
</p>
</ac:rich-text-body>
</ac:structured-macro>
DOCHERE
done

cat >> /tmp/chartpe.json <<DOCHERE
",
"representation":"storage"}},
"version":{"number":$Version}}
DOCHERE

./api.sh post chartpe.json $PageId
