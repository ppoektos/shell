#!/bin/bash
cd /opt/notifications || exit 11
DOM=`date --date= +%d`
BiWeeklyDays="11 12 13 14 15 16 17 25 26 27 28 29 30 31"
reportFile=CostBracketReport.html

ActiveProjectsIds=$(curl -sn https://<CONFLUENCE_HOST>/rest/api/content/<PAGE_ID_PROJECTS>?expand=body.storage \
                    | python -mjson.tool | grep -oE '[0-9]{8} - [a-zA-Z0-9 -]*')

UserGroups=$(mysql --login-path=<DB_LOGIN_PATH> -Nse "use <REDMINE_DB>; \
            SELECT possible_values FROM custom_fields WHERE id = '44';")


calc () { awk "BEGIN { print $*}"; }


cost_bracket () {

echo "<table border=\"1\" style=\"border-collapse: collapse;\" cellpadding="3">"
echo "<tr><th>$Word</th><th>Current year</th><th>Total</th></tr><tr>"

for Period in $Periods; do

    SumForPeriod=0

    case $Period in
        Week)
                        MysqlDate="time_entries.spent_on >= DATE(NOW()) - INTERVAL 7 DAY \
                                    AND time_entries.spent_on < CURDATE() AND"
        ;;
        BiWeek)
                        MysqlDate="time_entries.spent_on >= DATE(NOW()) - INTERVAL 14 DAY \
                                    AND time_entries.spent_on < CURDATE() AND"
        ;;
        Month)
                        MysqlDate="YEAR(time_entries.spent_on) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) \
                                    AND MONTH(time_entries.spent_on) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH) AND"
        ;;
        Year)           MysqlDate="YEAR(time_entries.spent_on) = YEAR(CURRENT_DATE) AND"
        ;;
        Total)          MysqlDate=
        ;;
    esac

    echo "<td>"

    while read -r Group; do

        Group_Hours=$(mysql --login-path=<DB_LOGIN_PATH> -Nse "use <REDMINE_DB>; \
                    SELECT SUM(ROUND(time_entries.hours, 2))
                    FROM time_entries
                    WHERE $MysqlDate
                    time_entries.project_id IN ($1)
                    AND user_id IN (SELECT customized_id
                                    FROM custom_values
                                    WHERE value LIKE '$Group');")

        if [ "$Group_Hours" != NULL ]; then

            echo "$Group - $Group_Hours<br>"

            SumForPeriod=$(calc $SumForPeriod + $Group_Hours)

        fi

    done < <(echo -e $UserGroups | tail -n +2 | head -n -1 | cut -c 3-)

    echo "</td>"

    SumArray+=($SumForPeriod)


done

echo "</tr><tr>"

for i in ${SumArray[@]}; do
   echo "<td>$i</td>"
done

echo "</tr></table><br>"

unset SumArray

}



main () {

while read -r Project; do

    > $reportFile

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

    if [ -z $parent ]; then
        echo "Error: <$Project> isn't root project."
        echo
        continue
    fi

    subprojects=($(mysql --login-path=<DB_LOGIN_PATH> -Nse "use <REDMINE_DB>; SELECT id FROM projects WHERE parent_id = '$parent';"))

    #echo "Main: $Project"
    #echo "Sub:"

        #for subProject in ${subprojects[@]}; do
        #    mysql --login-path=<DB_LOGIN_PATH> -Nse "use <REDMINE_DB>; SELECT name FROM projects WHERE id = '$subProject';"
        #done

    subprojects+=($parent)

    ProjectsIds=$(printf "%s," ${subprojects[@]})
    ProjectsIds=${ProjectsIds%,}

    ProjectMembers=($(mysql --login-path=<DB_LOGIN_PATH> -Nse \
                    "use <REDMINE_DB>; SELECT users.login
                    FROM users
                    INNER JOIN
                    members ON users.id = members.user_id
                    INNER JOIN
                    member_roles ON members.id = member_roles.member_id
                    WHERE members.project_id = '$parent'
                    AND member_roles.role_id = '3';"))

    if [ -z $ProjectMembers ]; then
        echo "Error: no PMs defined."
        echo
        continue
    fi

    ProjectMembers=$(printf "%s@<NOTIFY_EMAIL>," ${ProjectMembers[@]})
    ProjectMembers=${ProjectMembers%,}

    cost_bracket "$ProjectsIds" >> $reportFile

    mutt -e 'set content_type="text/html"' -s "Cost bracket report for $Project" -- $ProjectMembers < $reportFile

    unset subprojects
    unset ProjectMembers

    sleep 5

done <<< "$ActiveProjectsIds"

}


case $1 in
    week)   Periods="Week Year Total"
            Word="Week $(date --date="- 1 week" +%V)"

            main

            for i in $BiWeeklyDays; do

                if [ $DOM -eq $i ]; then

                    Periods="BiWeek Year Total"
                    Word="Weeks $(date --date="- 2 week" +%V)-$(date --date="- 1 week" +%V)"

                    main

                fi

            done
    ;;
    month)  Periods="Month Year Total"
            Word="Month $(date --date="last month" +%m)"

            main
    ;;
esac
