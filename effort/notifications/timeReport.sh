#!/bin/bash
cd /opt/notifications || exit 11

DEV="ach agr ama ato dka iot kch ksi mbe mis msn oos oru rmi spo sst svl vda vlm yho"
#office2="apa ddz ihr lha mta nma ose rbo tiv"
PM="spl sgr jsf"
TL="dgo sma osm vdo"
TLV="jei jsf isa"
MARKETING="gbc hjc"
CTO=ssh
ALI=ali
PD=ali
TRS=oto
D1="PM TL CTO DEV"
D2="TLV MARKETING TLI TRS"
TEAM="HW_office1 PM_office1 QA_office1 SW_office1 TLV PR_office2"
Exclusion="ami ali bsc dbu jho kpa lli nmj oko ose pba pmo ppj rsk sso tiv vfe vmi vgr"

CurrentYear=$(date +%Y)
PastYear=$(date +%Y -d 'last year')
CurrentMonth=$(date +%-m)
PastMonth=$(date +%-m -d 'last month')

if [ $CurrentMonth = 1 ]; then
    Date=$PastYear-$PastMonth-01
    YearToCompare=$PastYear
    else
    Date=$CurrentYear-$PastMonth-01
    YearToCompare=$CurrentYear
fi

WorkDaysTotal=$(cal -m $(date +%m -d 'last month') $YearToCompare \
                | tail -n +3 | cut -c1-14 | wc -w)


func_Usage () {
echo "Usage: $0 [ daily | weekly | monthly | chart [daily, weekly, monthly] ]"
exit 11
}


calc () { awk "BEGIN { print $*}"; }


if [ "$#" -eq 0 ]; then
        echo "Aborted, no parameters"
        func_Usage
    elif [ "$#" -gt 2 ]; then
        echo "Aborted, wrong number of parameters: $#"
        func_Usage
fi


zero () {
Zero_Persons=
ExclusionMysql=

for f in $Exclusion; do ExclusionMysql="$ExclusionMysql '$f',"; done

ExclusionMysql=$(echo ${ExclusionMysql%,})

while read -r users; do
    Zero_Persons="$Zero_Persons$users, "
done < <(mysql --login-path=<DB_LOGIN_PATH> -Ne  "use <REDMINE_DB>; \
        SELECT users.login \
        FROM users \
        INNER JOIN custom_values \
        ON users.id = custom_values.customized_id \
        WHERE users.login NOT IN \
            (SELECT users.login FROM users, time_entries \
            WHERE time_entries.spent_on = SUBDATE(CURDATE(),1) \
            AND time_entries.user_id = users.id) \
        AND users.status = 1 \
        AND users.login NOT IN ($ExclusionMysql) \
        AND custom_values.custom_field_id = 21 \
        AND custom_values.value != 'Customer' \
        ORDER BY users.login;")

echo "List of active users excluded from report: <b>$(echo $Exclusion | sed 's/ /, /g')</b>.<br><br>" > full.html
echo "Users who didn't log time yesterday: <b>${Zero_Persons%??}</b>.<br><br>" >> full.html
}


cost_bracket () {

Query=$(mysql --login-path=<DB_LOGIN_PATH> -Nse "use <REDMINE_DB>; \
        SELECT possible_values FROM custom_fields WHERE id = '44';")

echo "<br>Spent hours by employees' cost bracket assignment:<br>" >> full.html

echo -e "<table border=\"1\" style=\"border-collapse: collapse;\" cellpadding="3"> \
        \n<tr><th>Yesterday</th><th>In current month</th><th>In last month</th></tr> \
        \n<tr>" >> full.html

for Period in Day CurrentMonth LastMonth; do

    Month=$(date +%-m)
    Year=$(date +%Y)

    case $Period in
        Day)            Word="yesterday"
                        MysqlDate="time_entries.spent_on = SUBDATE(CURDATE(),1)"
        ;;
        CurrentMonth)   Word="in current month"
                        MysqlDate="month(time_entries.spent_on) = '$Month' AND year(time_entries.spent_on) = '$Year'"
        ;;
        LastMonth)      Word="in last month"
                        Month=$(date +%-m -d 'last month')
                        [[ $Month -eq 12 ]] && Year=$(date +%Y -d 'last year')
                        MysqlDate="month(time_entries.spent_on) = '$Month' AND year(time_entries.spent_on) = '$Year'"
        ;;
    esac

    echo "<td>" >> full.html

    echo -e $Query | tail -n +2 | head -n -1 | cut -c 3- | \
    while read -r Group; do

        Group_Hours=$(mysql --login-path=<DB_LOGIN_PATH> -Nse "use <REDMINE_DB>; \
                    SELECT SUM(ROUND(time_entries.hours, 2))
                    FROM time_entries
                    WHERE $MysqlDate
                    AND time_entries.project_id IN ($1)
                    AND user_id IN (SELECT customized_id
                                    FROM custom_values
                                    WHERE value LIKE '$Group');")

        if [ "$Group_Hours" != NULL ]; then
            echo "$Group - $Group_Hours<br>" >> full.html
        fi
    done

    echo "</td>" >> full.html

done
echo "</tr></table><br>" >> full.html
}



over_due_tasks () {

echo "Over due to tasks:<br>" >> full.html

while read DueToIssue; do
    echo "<a href=\"https://<REDMINE_HOST>/issues/$DueToIssue\">https://<REDMINE_HOST>/issues/$DueToIssue</a><br>" >> full.html
done < <(mysql --login-path=<DB_LOGIN_PATH> -Nse "use <REDMINE_DB>;
        SELECT issues.id
        FROM issues, projects
        WHERE issues.project_id = projects.id
        AND projects.id IN ($1)
        AND projects.status = '1'
        AND issues.status_id NOT IN (5,6)
        AND issues.due_date < curdate();")

}



projects () {
ActiveProjectsIds=$(curl -sn https://<CONFLUENCE_HOST>/rest/api/content/<PAGE_ID_PROJECTS>?expand=body.storage \
                    | python -mjson.tool | grep -oE '[0-9]{8} - [a-zA-Z0-9 -]*')

while read -r Project; do

    if [ "$Project" = "30041044 - Priess Light Column Controller" ]; then
        Project="30030063 - Priess Open Support"
    fi

    if [ "$Project" = "30030066 - Nilan Open Support Project" ]; then
        Project="30041091 - Nilan Fixed Team 2018"
    fi

    Id=${Project:0:8}
    lenght=${#Project}
    name=${Project:11:$lenght}

    parent=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
            "use <REDMINE_DB>; SELECT id FROM projects WHERE name LIKE '%$Id%' \
            AND projects.parent_id is NULL;")

    arr=(`mysql --login-path=<DB_LOGIN_PATH> -Nse \
        "use <REDMINE_DB>; SELECT id FROM projects WHERE parent_id = '$parent'"`)

    arr+=($parent)

    ProjectsIds=$(printf "%s," ${arr[@]})
    ProjectsIds=${ProjectsIds%,}

    echo -e "<hr>\n<b>$Project</b><br>" >> full.html

    sum=0

    declare -A arrsum

    for f in ${arr[@]}; do
        while IFS=$'\t' read login hours; do
            sum=$(calc $sum+$hours)
            arrsum["$login"]+="$hours+"
        done < <(mysql --login-path=<DB_LOGIN_PATH> -Nse \
                "use <REDMINE_DB>; SELECT users.login, SUM(ROUND(time_entries.hours, 2)) \
                FROM users INNER JOIN time_entries \
                ON users.id = time_entries.user_id \
                WHERE time_entries.spent_on = SUBDATE(CURDATE(),1) \
                AND time_entries.project_id = '$f' \
                AND time_entries.user_id = users.id \
                GROUP BY users.login;")
    done

    for i in "${!arrsum[@]}"; do echo "$i - $(calc $(echo ${arrsum[$i]%+}))<br>" >> full.html ; done

    [[ "$sum" != "0" ]] && echo "Total: <b>$sum</b><br>" >> full.html

    cost_bracket "$ProjectsIds"
    over_due_tasks "$ProjectsIds"

    #echo "--------------------------------------------------------------------------------------<br>" >> full.html
    unset arrsum
done <<< "$ActiveProjectsIds"
echo "<br>" >> full.html
}


dprtmnts () {
for dp in $TEAM; do

echo -e "\n<b>$dp team</b>.\n<table border=\"1\" style=\"border-collapse: collapse;\" cellpadding=\"3\">\n \
<tr><td style=\"text-align:center\">Person</td><td style=\"text-align:center\">Project</td><td>Issue</td><td style=\"text-align:center\">Spent hours</td></tr>" >> full.html

SumLogin=0
Sum=0
Next=
while IFS=$'\t' read -r login project issue hours; do

  if [ -n "$Next" -a "$Next" != "$login" ]; then
      echo "<tr><td></td><td>Total for <b>$Next</b></td><td></td><td style=\"text-align:center\"><b>$SumLogin</b></td></tr>" >> full.html
      SumLogin=0
  fi

  echo "<tr><td style=\"text-align:center\">$login</td><td>$project</td><td><a href=\"https://<REDMINE_HOST>/issues/$issue\">$issue</a></td><td style=\"text-align:center\">$hours</td></tr>" >> full.html

  Sum=$(calc $Sum+$hours); Next=$login; SumLogin=$(calc $SumLogin+$hours)

done < <(mysql --login-path=<DB_LOGIN_PATH> -N -e  "use <REDMINE_DB>; \
        SELECT users.login, projects.name, time_entries.issue_id, ROUND(time_entries.hours, 2) \
        FROM users INNER JOIN custom_values \
        ON users.id = custom_values.customized_id,
        time_entries INNER JOIN projects \
        ON time_entries.project_id = projects.id \
        WHERE time_entries.spent_on = SUBDATE(CURDATE(),1) \
        AND time_entries.user_id = users.id \
        AND custom_values.value = '$dp' \
        ORDER BY users.login;")

echo "<tr><td></td><td>Total for <b>$Next</b></td><td></td><td><b>$SumLogin</b></td></tr>" >> full.html
echo -e "</table>\n$dp team spent <b>$Sum</b> hours yesterday.<br><br>" >> full.html
done
}


holiday_old () {
hol=0
Ua="01.01 08.01 08.03 29.04 01.05 09.05 17.06 28.06 26.08 14.10 25.12"
Dk="01.01 18.04 19.04 21.04 22.04 17.05 30.05 09.06 10.06 24.12 25.12 26.12"

if [ "$1" = "ua" ]; then
  Holiday=$Ua
  else
  Holiday=$Dk
fi

for f in $Holiday; do
  a=$(echo ${f#*.} | grep -c `date --date="last month" +%m`)
  hol=$(($hol + $a))
done;
}


holiday () {
hol=0
Ua="01.01 08.01 08.03 29.04 01.05 09.05 17.06 28.06 26.08 14.10 25.12"
Dk="01.01 18.04 19.04 21.04 22.04 17.05 30.05 09.06 10.06 24.12 25.12 26.12"
LastMonth=$(date --date="last month" +%m)

if [ "$1" = "ua" ]; then
  Holiday=$Ua
  else
  Holiday=$Dk
fi


for f in $Holiday; do

    #a=$(echo ${f#*.} | grep -c $LastMonth)
    #hol=$(($hol + $a))



   if echo ${f#*.} | grep -q $LastMonth ; then

        DayOfHoliday=${f%.*}
        DayOfHoliday=${DayOfHoliday/#0/}

        [[ -n $StartWorkDay ]] && StartWorkDay=${StartWorkDay/#0/}
        [[ -n $FinishWorkDay ]] && FinishWorkDay=${FinishWorkDay/#0/}


        if [[ -n $StartWorkDay ]] && [[ -n $FinishWorkDay ]]; then

           if [[ $DayOfHoliday -gt $StartWorkDay ]] && [[ $DayOfHoliday -lt $FinishWorkDay ]]; then

                ((hol++))
                echo "Holiday is between StartWorkDay and FinishWorkDay. Adding it."

           fi
         fi


        if [[ -n $StartWorkDay ]] && [[ -z $FinishWorkDay ]]; then

            if [[ $DayOfHoliday -gt $StartWorkDay ]]; then

                ((hol++))
                echo "Holiday is after StartWorkDay. Adding it."

            fi

        fi


        if [[ -n $FinishWorkDay ]] && [[ -z $StartWorkDay ]]; then

            if [[ $DayOfHoliday -lt $FinishWorkDay ]]; then

                ((hol++))
                echo "Holiday is before FinishWorkDay. Adding it."

            fi

        fi


        [[ -z $FinishWorkDay ]] && [[ -z $StartWorkDay ]] && ((hol++))


    fi

done;

}


nominalworkdays () {

if [ $2 = 0 ]; then
    user_nominal=0
    WorkDays=0
    #echo "NominalWorkingHours: $user_nominal<br>"
    return
fi

#if [ $1 = yly -o $1 = voi ]; then
#    WorkDays=$(echo $2 $WorkDaysTotal | awk '{print int($1/$2)}')
    #echo $1 $WorkDays
#    return
#fi

WorkDays=$WorkDaysTotal
StartWorkDay=
FinishWorkDay=

for DateToCompare in "Start day" "Finish day"; do

        DateValue=$(mysql --login-path=<DB_LOGIN_PATH> -Ns -e \
                    "use <REDMINE_DB>; SELECT value FROM custom_values \
                    WHERE customized_id = (SELECT id FROM users WHERE login = '$1') \
                    AND custom_field_id = (SELECT id FROM custom_fields WHERE name = '$DateToCompare')")

        if [ -n "$DateValue" ]; then
            DateValueYear=$(date -d $DateValue '+%Y')
            else
            continue
        fi

        if [ $YearToCompare = $DateValueYear ]; then
             DateValueMonth=$(date -d $DateValue '+%-m')
             else
             continue
        fi

        if [ "$PastMonth" = "$DateValueMonth" ]; then
            #echo "$DateToCompare - $DateValue<br>"
            DateValueDay=$(date -d $DateValue '+%-d')
            else
            continue
        fi

        WorkDaysValue=$(cal -hM $(date +%m -d 'last month') $YearToCompare \
                       | tail -n +3 | cut -c1-14 | fmt -w 1 | sort -n | sed "/^$/d" \
                       | grep -wn $DateValueDay | awk -F: '{print $1}')


        case ${DateToCompare% day} in
            Start) #echo "Working days are from the Start day [$DateValueDay] till the end of month.<br>"
                   WorkDays=$((WorkDaysTotal - WorkDaysValue + 1))
                   StartWorkDay=$WorkDaysValue
            ;;
            Finish) #echo "Workings days are from the start of month till Finish day [$DateValueDay].<br>"
                    WorkDays=$WorkDaysValue
                    FinishWorkDay=$WorkDaysValue
            ;;
        esac
done

if [ -n "$StartWorkDay" ] && [ -n "$FinishWorkDay" ]; then
    WorkDays=$((FinishWorkDay - StartWorkDay + 1))
fi

}


func_Report () {

while IFS=$'\t' read -r user hours; do

    if echo "$PM" | grep -q $user; then
        PM_table="$PM_table\n<tr><td>$user</td><td>$hours</td></tr>"
        PM_sum=$(calc $PM_sum+$hours)

        nominalworkdays $user $hours

        case $user in
                jsf)    holiday dk
                        PM_nominal=$(calc $PM_nominal+\($WorkDays-$hol\)*5.7 )
                        #PM_nominal=$(calc $PM_nominal+$WorkDays*5.7 )

                        TLV_table="$TLV_table\n<tr><td>$user</td><td>$hours</td></tr>"
                        TLV_sum=$(calc $TLV_sum+$hours)

                  ;;
                  *)    holiday ua
                        PM_nominal=$(calc $PM_nominal+\($WorkDays-$hol\)*8 )
                        #PM_nominal=$(calc $PM_nominal+$WorkDays*8)
                  ;;
        esac



       # if [ $user = hra ]; then
       #     MARKETING_table="$MARKETING_table\n<tr><td>$user</td><td>$hours</td></tr>"
       #     MARKETING_sum=$(calc $MARKETING_sum+$hours)
       # fi


    elif echo "$TL" | grep -q $user; then
        TL_table="$TL_table\n<tr><td>$user</td><td>$hours</td></tr>"
        TL_sum=$(calc $TL_sum+$hours)
        nominalworkdays $user $hours
        holiday ua
        TL_nominal=$(calc $TL_nominal+\($WorkDays-$hol\)*8 )
    elif echo "$CTO" | grep -q $user; then
        CTO_table="<tr><td>$user</td><td>$hours</td></tr>"
        CTO_sum=$hours
        nominalworkdays $user $hours
        holiday ua
        CTO_nominal=$(calc $CTO_nominal+\($WorkDays-$hol\)*8 )
    elif echo "$DEV" | grep -q $user; then
        DEV_table="$DEV_table\n<tr><td>$user</td><td>$hours</td></tr>"
        DEV_sum=$(calc $DEV_sum+$hours)
        nominalworkdays $user $hours
        holiday ua
        DEV_nominal=$(calc $DEV_nominal+\($WorkDays-$hol\)*8 )
    elif echo "$TLI" | grep -q $user; then
        TLI_table="$TLI_table\n<tr><td>$user</td><td>$hours</td></tr>"
        TLI_sum=$(calc $TLI_sum+$hours)
    elif echo "$TRS" | grep -q $user; then
        TRS_table="<tr><td>$user</td><td>$hours</td></tr>"
        TRS_sum=$hours
    elif echo "$TLV" | grep -q $user; then
        TLV_table="$TLV_table\n<tr><td>$user</td><td>$hours</td></tr>"
        TLV_sum=$(calc $TLV_sum+$hours)
    elif echo "$MARKETING" | grep -q $user; then
        MARKETING_table="$MARKETING_table\n<tr><td>$user</td><td>$hours</td></tr>"
        MARKETING_sum=$(calc $MARKETING_sum+$hours)
    fi


done < <(mysql --login-path=<DB_LOGIN_PATH> -N -e  "use <REDMINE_DB>; \
        SELECT users.login, SUM(ROUND(time_entries.hours, 2)) \
        FROM time_entries, users \
        WHERE $rangeFrom \
        AND $rangeTill \
        AND time_entries.user_id = users.id \
        AND users.login NOT LIKE '%Cat%' \
        GROUP BY users.login;")

DEV_total=$(calc $PM_sum+$TL_sum+$CTO_sum+$DEV_sum)

for departmentGroup_temp in D1 D2; do
    eval departmentGroup="$"$departmentGroup_temp
    #echo $departmentGroup

    if [ "$departmentGroup_temp" = "D1" ]; then
        recipients="<PM_EMAIL>,<MANAGER_EMAIL>,<CTO_EMAIL>,<NOTIFY_EMAIL>"
        subject="$Date DEV team timesheet"
        else
        recipients="<TLV_EMAIL>,<ADMIN_EMAIL>"
        subject="$Date team timesheet"
    fi

    > $reportFile

    for department_temp in $departmentGroup; do

       eval department_name="$"$department_temp
       eval department="$"${department_temp}_table
       eval sum="$"${department_temp}_sum

       #department_nominal=

       for user_name in $department_name; do
            if ! echo $department | grep -q $user_name; then
                department="$department\n<tr><td>$user_name</td><td>0</td></tr>"
            fi
       done

       if [[ $departmentGroup_temp = D1 ]] && [[ $department_temp = PM ]]; then

           # Number of DK users in PM group.
           # Must be specified since nominal work hours are different in UA/DK.
           # And we summarize nominal UA/DK hours.

           DK_users=1 # Only JSF and she has 28.5 hours per week

           department_sum=$(echo $department_name | wc -w)

                if [ "$1" = monthly ]; then
                    #department_nominal=$(echo "$department_sum $DK_users $WorkDays" | awk '{print ($1 - $2)*8*$3 + $2*7.4*$3}')
                    eval department_nominal="$"${department_temp}_nominal
                    else
                    department_nominal=$(echo "$department_sum $DK_users" | awk '{print ($1 - $2)*40 + $2*28.5}')
                fi

           elif [[ $departmentGroup_temp = D1 ]]; then

                if [ "$1" = monthly ]; then
                    #department_nominal=$(($(echo $department_name | wc -w) * 8 * $WorkDays))
                    eval department_nominal="$"${department_temp}_nominal
                    else
                    department_nominal=$(($(echo $department_name | wc -w) * 40))
                fi

           else
           department_nominal=0
       fi

       if [[ $departmentGroup_temp = D1 ]]; then
            NOMINAL_total=$(calc $NOMINAL_total+$department_nominal)
       fi

       echo -e "<b>$department_temp</b>\n<table border=\"1\" style=\"border-collapse: collapse;\" cellpadding=\"3\">\n\
<tr><th>User</th><th>Hours</th></tr>$department\n</table>\n\
Total: $sum. Nominal: $department_nominal.<br><br>" >> $reportFile

    done

        if [[ $departmentGroup_temp = D1 ]]; then
            echo "DEV_TOTAL: $DEV_total.<br>NOMINAL_TOTAL: $NOMINAL_total." >> $reportFile
        fi

        #exit 55
    mutt -e 'set content_type="text/html"' -s "$subject" -- $recipients < $reportFile

    #exit 66
done
}



chartReport () {

#if [ $1 = daily ]; then
#    echo $1
#    exit 11
#fi

cd /tmp || exit 11
rm -f ./*.html

chartMainFunction () {

MuttFile=

for group_ in $1; do

    eval group="$"$group_
    FileName=${group_}_${DateTitle}.html
    MuttFile="$MuttFile $FileName"

cat > $FileName <<EOF
<html>
  <head>
    <title>$group_ $DateTitle time report</title>
    <style>
    svg > g > g:last-child { pointer-events: none }
    </style>
    <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
    <script type="text/javascript">
      google.charts.load('current', {'packages':['corechart']});
EOF

    for user in $group; do

    TitleCapital=$(echo $user | tr '[:lower:]' '[:upper:]')
    Sum=0
    Hours_Dev=0

cat >> $FileName <<EOF
      google.charts.setOnLoadCallback(drawChart_$user);
      function drawChart_$user() {
        var data = new google.visualization.DataTable();
        data.addColumn('string', 'Title');
        data.addColumn('number', 'Value');
        data.addRows([
EOF

    while IFS=$'\t' read parent_id project_name hours; do

        # if project_id is in array of active projects
        # then echo hours to html and add Sum_Proj

        if [[ "$project_name" =~ ^300[3-4,7].* ]]; then

            IsDevelopment=true

            elif [[ $parent_id != "NULL" ]]; then

            ParentName=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
                        "use <REDMINE_DB>; SELECT projects.name FROM projects \
                        WHERE projects.id = '$parent_id';")

            [[ "$ParentName" =~ ^300[3-4,7].* ]] && IsDevelopment=true || IsDevelopment=false

        fi

        if $IsDevelopment; then
            echo "['$project_name', $hours]," >> $FileName
            Hours_Dev=$(calc $Hours_Dev+$hours)
        fi

        Sum=$(calc $Sum+$hours)

    done < <(mysql --login-path=<DB_LOGIN_PATH> -Nse  "use <REDMINE_DB>;
            SELECT ANY_VALUE(projects.parent_id), projects.name, sum(round(time_entries.hours,2))
            FROM users, time_entries INNER JOIN projects
            ON time_entries.project_id = projects.id
            WHERE $MysqlDate
            AND time_entries.user_id = users.id
            AND users.login = '$user'
            GROUP BY projects.name;")

    if [ x$Sum != x0 ]; then

        Hours_Non=$(calc $Sum-$Hours_Dev)
        else
        Hours_Non=0

    fi


cat >> $FileName <<EOF
]);
        var options = { title:'$TitleCapital - $Sum hours.',
                        legend: {position: 'labeled'},
                        pieSliceText:'value',
                        width:700,
                        height:300,
                        chartArea: {width:'100%',height:'100%',left:20,top:80},
                        fontSize:20,
                       };
        var chart = new google.visualization.PieChart(document.getElementById('chart_div_$user'));
        chart.draw(data, options);
      }

      google.charts.setOnLoadCallback(drawChart_${user}_p);
        function drawChart_${user}_p() {
        var data = new google.visualization.DataTable();
        data.addColumn('string', 'Title');
        data.addColumn('number', 'Value');
        data.addRows([
['Project', $Hours_Dev],
['Non', $Hours_Non],
]);
        var options = { title:' ',
                        legend: {position: 'labeled'},
                        pieSliceText:'value',
                        colors:['lightseagreen','deepskyblue'],
                        width:700,
                        height:200,
                        chartArea: {left:400,top:20},
                        fontSize:20,
                       };
        var chart = new google.visualization.PieChart(document.getElementById('chart_div_${user}_p'));
        chart.draw(data, options);
      }

EOF
    done

cat >> $FileName <<EOF
    </script>
  </head>
  <body>
EOF

for user in $group; do
    echo "<div id="chart_div_$user"></div>" >> $FileName
    echo "<div id="chart_div_${user}_p"></div><hr>" >> $FileName
done

cat >> $FileName <<EOF
  </body>
</html>
EOF

done

mutt -e 'set content_type="text/html"' -s "DEV Productivity Charts $DateTitle" -a $MuttFile -- $recipients < /opt/notifications/chart.body

}



chartToAll () {

GroupAll="$Group1 $Group2"


for subGroup in $GroupAll; do

    eval subUsers="$"$subGroup

    users="$subUsers $users"

done

users=$(echo $users | tr " " "\n" | sort -u | tr "\n" " ")


# manual pass for one user
#users=ppo

for user in $users; do

    #echo $user

    [[ $user = ali ]] || [[ $user = osh ]] || [[ $user = dpe ]] && continue

    TitleCapital=$(echo $user | tr '[:lower:]' '[:upper:]')
    FileName=${TitleCapital}_${DateTitle}.html
    Sum=0

cat > $FileName <<EOF
<html>
  <head>
    <title>$FileName time report</title>
    <style>
    svg > g > g:last-child { pointer-events: none }
    </style>
    <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
    <script type="text/javascript">
      google.charts.load('current', {'packages':['corechart']});
      google.charts.setOnLoadCallback(drawChart_$user);
      function drawChart_$user() {
        var data = new google.visualization.DataTable();
        data.addColumn('string', 'Title');
        data.addColumn('number', 'Value');
        data.addRows([
EOF

    while IFS=$'\t' read project hours; do
        echo "['$project', $hours]," >> $FileName
        Sum=$(calc $Sum+$hours)
    done < <(mysql --login-path=<DB_LOGIN_PATH> -Nse  "use <REDMINE_DB>;
            SELECT projects.name, sum(round(time_entries.hours,2))
            FROM users, time_entries INNER JOIN projects
            ON time_entries.project_id = projects.id
            WHERE $MysqlDate
            AND time_entries.user_id = users.id
            AND users.login = '$user'
            GROUP BY projects.name;")

cat >> $FileName <<EOF
]);
        var options = { title:'$TitleCapital - $Sum',
                        legend: {position: 'labeled'},
                        pieSliceText:'value',
                        width:700,
                        height:300,
                        chartArea: {width:'100%',height:'100%',left:20,top:80},
                        fontSize:20,
                       };
        var chart = new google.visualization.PieChart(document.getElementById('chart_div_$user'));
        chart.draw(data, options);
      }
    </script>
  </head>
  <body>
    <div id="chart_div_$user"></div>
  </body>
</html>
EOF

mutt -e 'set content_type="text/html"' -s "Productivity Charts $DateTitle" -a $FileName -- ${user}@<NOTIFY_EMAIL> < /opt/notifications/chart.body

    sleep 10

done

}



case "$1" in
    daily)      MysqlDate="time_entries.spent_on = SUBDATE(CURDATE(),1)"
                DateTitle=$(date --date="1 day ago" +%Y%m%d)

    ;;
    weekly)     MysqlDate="time_entries.spent_on >= DATE(NOW()) - INTERVAL 7 DAY AND time_entries.spent_on < CURDATE()"
                DateTitle="week_$(date --date="2 day ago" +%V)"

    ;;
    monthly)    MysqlDate="YEAR(time_entries.spent_on) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) AND MONTH(time_entries.spent_on) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH)"
                DateTitle="month_$(date --date="last month" +%-m)"

    ;;
    *)          func_Usage
    ;;
esac


Group1="PM TL CTO PD"
Group2="TL DEV"
Group3=ALL
GroupAll="Group1 Group2 Group3"


# manual pass for one user
#GroupAll="Group3"

for Group_ in $GroupAll; do

    case $Group_ in
        Group1) [[ x$1 = xdaily ]] && continue
                recipients="<PM_EMAIL>"
        ;;
        Group2) recipients="<CTO_EMAIL>"
        ;;
        Group3) recipients=
                #exit 11
        ;;
    esac

    eval Group="$"$Group_

    if [ "$Group" = ALL ]; then
        chartToAll
        else
        chartMainFunction "$Group"
    fi

done

}



case "$1" in
    monthly)    Date="Month $(date --date="last month" +%-m)"
                reportFile="month.html"
                rangeFrom="YEAR(time_entries.spent_on) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH)"
                rangeTill="MONTH(time_entries.spent_on) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH)"
                func_Report $1
    ;;
    weekly)     Date="Week $(date --date="2 day ago" +%V)"
                reportFile="week.html"
                rangeFrom="time_entries.spent_on >= DATE(NOW()) - INTERVAL 7 DAY"
                rangeTill="time_entries.spent_on < CURDATE()"
                func_Report
    ;;
    daily)      Date=$(date --date="1 day ago" +%A,\ %d/%m/%Y)
                zero; projects; dprtmnts
                mutt -e 'set content_type="text/html"' -s "Daily spent time report. $Date" -- <PM_EMAIL>,<TL_EMAIL> < full.html
    ;;
    chart)      chartReport $2
    ;;
    *)          func_Usage
    ;;
esac
