#!/bin/bash

cd /tmp || exit 11

office1="aab ato dgo iot kch ksi mbe msn ool oru osm oto rmi sgr sma spo sst vlm yho"
office1_1="dgo iot mbe ool osm oto sgr vlm"
office1_2="ach ama dka mis ssh svl vdo"


proj () {

while read project; do

      echo "$project<br>"

done < <(mysql --login-path=<DB_LOGIN_PATH> -Ns -e "use <REDMINE_DB>;
         SELECT DISTINCT projects.name
         FROM projects, time_entries, users
         WHERE $MysqlDate
         AND projects.id =  time_entries.project_id
         AND time_entries.user_id = users.id
         AND users.login = '$User';")
}


func_Usage () {
echo "Usage: $0 [ daily | weekly ]"
exit 11
}



if [ "$#" -eq 0 ]; then
        echo "Aborted, no parameters"
        func_Usage
    elif [ "$#" -gt 1 ]; then
        echo "Aborted, wrong number of parameters: $#"
        func_Usage
fi



case "$1" in
    daily)      MysqlDate="time_entries.spent_on = SUBDATE(CURDATE(),1)"
                DateTitle=$(date --date="1 day ago" +%Y-%m-%d)

    ;;
    weekly)     MysqlDate="time_entries.spent_on >= DATE(NOW()) - INTERVAL 7 DAY AND time_entries.spent_on < CURDATE()"
                DateTitle="week_$(date --date="2 day ago" +%V)"

    ;;
esac


for Office_tmp in office1 office1_2; do

    case $Office_tmp in

        office1)  Recipient="<PM_EMAIL>"
        ;;
        office1_1) Recipient="<TL_EMAIL>"
        ;;
        office1_2) Recipient="<CTO_EMAIL>"
        ;;

    esac

    eval Office="$"$Office_tmp

    #Recipient="<ADMIN_EMAIL>"

    echo -e "<table border=\"1\" style=\"border-collapse: collapse;\" cellpadding="3"> \
        \n<tr><th>User</th><th>Spent time</th><th>Projects</th></tr>" > $Office_tmp

    for User in $Office; do

        echo "<tr>" >> $Office_tmp

        echo "<td>$User</td>" >> $Office_tmp

        Time=$(mysql --login-path=<DB_LOGIN_PATH> -Ns -e "use <REDMINE_DB>; \
                SELECT IFNULL(SUM(ROUND(time_entries.hours, 2)), '0') \
                FROM time_entries, users \
                WHERE $MysqlDate \
                AND time_entries.user_id = users.id \
                AND users.login = '$User';")

        echo "<td>$Time</td>" >> $Office_tmp

        echo "<td>$( proj )</td>" >> $Office_tmp

        echo "</tr>" >> $Office_tmp

    done


    echo "</table>" >> $Office_tmp

    mutt -e 'set content_type="text/html"' -s "Split team timesheet $Office_tmp for $DateTitle" -- $Recipient < $Office_tmp

    sleep 5

done
