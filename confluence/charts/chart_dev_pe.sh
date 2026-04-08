#!/bin/bash
cd /root/scripts || exit 1
Month=$(date +%-m)
DEVfile=/tmp/chartdevpe.json
Groups="TL PM SW HW QC CTO PD"
Types="nominal registered invoiced noninvoiced sales meeting pmo ill holiday other"
MemberTotal=
MemberTotalComma=
Overview=
Version=$(./api.sh version <PAGE_ID>)
((Version++))

calc () { awk "BEGIN { print $*}"; }

case $Month in
    1) Year=$(date +%Y -d 'last year')
    ;;
    *) Year=$(date +%Y)
    ;;
esac


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
    pmo) Cell=PMO
    ;;
    ill) Cell=Ill
    ;;
    holiday) Cell=Holidays
    ;;
    other) Cell=Other
    ;;
    *) Cell="$1"
    ;;
esac
}


month_row () {

while read month date; do
     echo "<td>$month</td>" >> $DEVfile
done < <(mysql --login-path=<DB_NAME> -Nse \
         "use effort; SELECT DISTINCT monthname(date), date
          FROM users WHERE year(date) = '$Year'
          ORDER BY month(date);")
}


members_month_count () {

c=0
for m in $1; do

    IdByMonth=$(mysql --login-path=<DB_NAME> -Nse \
                "use effort; SELECT id FROM users
                 WHERE user = '$m' AND year(date) = '$Year'
                 AND month(date) = '$MonthName';")

    if [ "${IdByMonth:-0}" -gt 0 ]; then
       ((c++))
    fi

done

}


PrintCell () {

if [ x$1 = xprintdiff ]; then

        if [ $SumDataDevidedPrev = 0 ]; then

            Difference=0
            TextTag="<span style=\\\"color: rgb(0,0,0);\\\">"

            echo "<td>$SumDataDevided</td>" >> $DEVfile

            else

            Difference=$(calc $SumDataDevided-$SumDataDevidedPrev)

            if echo $Difference | grep -qv - ; then
                Difference=+$Difference
                TDTag="<td class=\\\"highlight-green\\\" data-highlight-colour=\\\"green\\\" title=\\\"Background colour : Green\\\">"
                TextTag="<span style=\\\"color: rgb(51,153,102);\\\">"
                else
                TDTag="<td class=\\\"highlight-red\\\" data-highlight-colour=\\\"red\\\" title=\\\"Background colour : Red\\\">"
                TextTag="<span style=\\\"color: rgb(255,0,0);\\\">"
            fi

            if echo $Difference | grep -qx +0 ; then
                Difference=0
                TDTag="<td>"
                TextTag="<span style=\\\"color: rgb(0,0,0);\\\">"
            fi

            echo "$TDTag$SumDataDevided ($Difference)</td>" >> $DEVfile

        fi

        [[ $Group != CTO ]] && [[ $Group != PD ]] &&
        if [ $MonthName -eq $(date +'%-m' -d 'last month') -a $f != pe ]; then
            Overview="$Overview $f = $SumDataDevided ($TextTag$Difference</span>) "
        fi

        [[ $Group = DEV ]] && [[ $MonthName -eq $(date +'%-m' -d 'last month') ]] && [[ $f = pe ]] &&
        Overview="$Overview $f = $SumDataDevided ($TextTag$Difference</span>)"

    SumDataDevidedPrev=$SumDataDevided

    else
    echo "<td>$SumDataDevided</td>" >> $DEVfile
fi

}


get_Yaxis_values () {

if [ "$1" = "Total" ]; then
    MembersToCount="$MemberTotal"
    else
    MembersToCount="$Members"
fi

for f in prod eff pe; do

    while read MonthName SumData; do

         members_month_count "$MembersToCount"

         ArrayOfValues+=( $(echo "$SumData $c" | awk '{printf "%.1f\n",  $1 / $2}') )

    done < <(mysql --login-path=<DB_NAME> -Nse \
            "use effort; SELECT month(date), sum($f)
            FROM users WHERE user IN ($2)
            AND year(date) = '$Year'
            GROUP BY month(date)
            ORDER BY month(date);")

done

SaveIFS=$IFS
IFS=$'\n'

LowerY=$(echo "${ArrayOfValues[*]}" | sort -n | head -1)
LowerY=$(printf "%.0f\n" $LowerY | awk '{print int(($1+5)/10) * 10 - 10}')
UpperY=$(echo "${ArrayOfValues[*]}" | sort -n | tail -1)
UpperY=$(printf "%.0f\n" $UpperY | awk '{print int(($1+5)/10) * 10 + 10}')

IFS=$SaveIFS
unset ArrayOfValues
}


chart_create () {

if [ "$1" = "Total" ]; then
    MembersToCount="$MemberTotal"
    else
    MembersToCount="$Members"
fi

for f in prod eff pe; do
    func_rename $f
    echo -e "</tr>\n<tr>\n<td>$Cell</td>" >> $DEVfile

    SumDataDevidedPrev=0

    while read MonthName SumData; do

         members_month_count "$MembersToCount"

         SumDataDevided=$(echo "$SumData $c" | awk '{printf "%.1f\n",  $1 / $2}')

         PrintCell $3

    done < <(mysql --login-path=<DB_NAME> -Nse \
            "use effort; SELECT month(date), sum($f)
            FROM users WHERE user IN ($2)
            AND year(date) = '$Year'
            GROUP BY month(date)
            ORDER BY month(date);")

done

}


table_create () {

for f in $Types; do
    func_rename $f
    echo -e "</tr>\n<tr>\n<th>$Cell</th>" >> $DEVfile

    while read i; do
         echo "<td style=\\\"text-align: center;\\\">$i</td>" >> $DEVfile
    done < <(mysql --login-path=<DB_NAME> -Nse \
             "use effort; SELECT round(sum($f),0) FROM users
              WHERE user IN ($1) AND year(date) = '$Year'
              GROUP BY month(date)
              ORDER BY month(date);")
done
}


cat > $DEVfile <<DOCHERE
{"id":"<PAGE_ID>",
"type":"page",
"title":"DEV charts",
"space":{"key":"<SPACE_KEY>"},
"body":
{"storage":
{"value":
"<p class=\"auto-cursor-target\"><br/></p>
<p>This page is auto-generated and shows statistic for $Year year.</p>
<p>You can find statistic for past year in the history of this page.</p>
<p>
  <ac:link ac:anchor=\"Overview\">
    <ac:plain-text-link-body><![CDATA[E&P Overview]]></ac:plain-text-link-body>
  </ac:link>
</p>
<br></br>
DOCHERE


for Group in $Groups; do

    [[ $Group != CTO ]] && [[ $Group != PD ]] && Overview="$Overview<br/>$Group:"

    Members=$(./api.sh get <PAGE_ID_MEMBERS> | grep value | grep -Po "$Group</td>.*?</td>" | grep -oE "[a-z ]+" | grep -v td)

    if [ x$Group != xPD ]; then
        MemberTotal="$Members $MemberTotal"
    fi

    Members_count=$(echo "$Members" | wc -w)

    MemberComma=

    for Member in $Members; do
        MemberComma="'$Member', $MemberComma"
    done

    MemberComma=${MemberComma%, }

    if [ x$Group != xPD ]; then
        MemberTotalComma="$MemberComma, $MemberTotalComma"
    fi

    MemberTotalComma=${MemberTotalComma%, }

    get_Yaxis_values "$Members_count" "$MemberComma"

cat >> $DEVfile <<DOCHERE
<ac:structured-macro ac:macro-id=\"0b097072-023b-434b-9407-d4682fd935c2\" ac:name=\"chart\" ac:schema-version=\"1\">
<ac:parameter ac:name=\"width\">800</ac:parameter>
<ac:parameter ac:name=\"title\">$Group</ac:parameter>
<ac:parameter ac:name=\"type\">line</ac:parameter>
<ac:parameter ac:name=\"rangeAxisTickUnit\">10</ac:parameter>
<ac:parameter ac:name=\"rangeAxisLowerBound\">$LowerY</ac:parameter>
<ac:parameter ac:name=\"rangeAxisUpperBound\">$UpperY</ac:parameter>
<ac:rich-text-body>
<p class=\"auto-cursor-target\">
<br/>
</p>
<table class=\"wrapped\">
<tbody>
<tr>
<td><br/></td>
DOCHERE

    month_row

    chart_create "$Members_count" "$MemberComma"

cat >> $DEVfile <<DOCHERE
</tr>
</tbody></table>
<p><br/></p>
<p class=\"auto-cursor-target\">
<br/>
</p>
</ac:rich-text-body>
</ac:structured-macro>
<p><br/></p>
<table class=\"wrapped\">
<tbody>
<tr>
<th style=\"text-align: center;\">$Group hours</th>
DOCHERE

    month_row

    table_create "$MemberComma"

    chart_create "$Members_count" "$MemberComma" printdiff

cat >> $DEVfile <<DOCHERE
</tr>
</tbody></table>
<p><br/></p>
DOCHERE

done

MembersTotalCount=$(echo "$MemberTotalComma" | wc -w)

    get_Yaxis_values "Total" "$MemberTotalComma"

cat >> $DEVfile <<DOCHERE
<ac:structured-macro ac:macro-id=\"0b097072-023b-434b-9407-d4682fd935c2\" ac:name=\"chart\" ac:schema-version=\"1\">
<ac:parameter ac:name=\"width\">800</ac:parameter>
<ac:parameter ac:name=\"title\">DEV</ac:parameter>
<ac:parameter ac:name=\"type\">line</ac:parameter>
<ac:parameter ac:name=\"rangeAxisTickUnit\">10</ac:parameter>
<ac:parameter ac:name=\"rangeAxisLowerBound\">$LowerY</ac:parameter>
<ac:parameter ac:name=\"rangeAxisUpperBound\">$UpperY</ac:parameter>
<ac:rich-text-body>
<p class=\"auto-cursor-target\">
<br/>
</p>
<table class=\"wrapped\">
<tbody>
<tr>
<td><br/></td>
DOCHERE

    month_row

    chart_create "Total" "$MemberTotalComma"

cat >> $DEVfile <<DOCHERE
</tr>
</tbody></table>
<p><br/></p>
<p class=\"auto-cursor-target\">
<br/>
</p>
</ac:rich-text-body>
</ac:structured-macro>
<p><br/></p>
<table class=\"wrapped\">
<tbody>
<tr>
<th style=\"text-align: center;\">DEV hours</th>
DOCHERE

    Overview="$Overview<br/>Overall DEV:"
    Group=DEV

    month_row

    table_create "$MemberTotalComma"

    chart_create "Total" "$MemberTotalComma" printdiff

cat >> $DEVfile <<DOCHERE
</tr>
</tbody></table>
<p>
  <ac:structured-macro ac:macro-id=\"62e38c8e-96a5-4f62-869e-ba6c6eb84330\" ac:name=\"anchor\" ac:schema-version=\"1\">
    <ac:parameter ac:name=\"\">Overview</ac:parameter>
  </ac:structured-macro>
$Overview
</p>
",
"representation":"storage"}},
"version":{"number":$Version}}
DOCHERE

./api.sh post chartdevpe.json <PAGE_ID>
