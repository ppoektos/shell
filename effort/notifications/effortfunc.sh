#!/bin/bash
#set -x
DB="<REDMINE_DB>"
CurrentYear=$(date +%Y)
PastYear=$(date +%Y -d 'last year')
CurrentMonth=$(date +%-m)
PastMonth=$(date +%-m -d 'last month')
Dom=`date --date= +%d`
List="11 12 13 14 15 16 17 25 26 27 28 29 30 31"
Teams="office1 office3 office4 ADMIN"
TLs="dgo jsf osm spl sgr sma ssh vdo"
office1="ach agr ama ato dgo dka iot kch ksi mbe mis msn oos oru \
osm oto rmi sgr sma spo spl ssh sst svl vda vdo vlm yho"
#office1="dpe osh"
#office2="apa ddz ihr lha phe mta nma rbo rho"
office3="dza jei jsf"
office4=oto
ADMIN="ali hjc isa osy ppo"
SWDE="ach agr ato dka iot mis msn oos oru sst svl vda yho"
HWDE="ama dza kch ksi mbe spo vlm"
QCDE="rmi"
user_nominal=

# Use blank to prevent database update
UpdateMysql=true
#Teams="office1"
#office1=ssh

# Date overwrite for recalc past data
MysqlDateMonth="MONTH(CURRENT_DATE - INTERVAL 1 MONTH)"
#MysqlDateMonth=6
#PastMonth=6

####################################################################

if [ $CurrentMonth = 1 ]; then
    Date=$PastYear-$PastMonth-01
    YearToCompare=$PastYear
    else
    Date=$CurrentYear-$PastMonth-01
    YearToCompare=$CurrentYear
fi

calc () { awk "BEGIN { print $*}"; }

init_vars () {

Activities="prod eff nominal registered invoiced noninvoiced sales meeting pmo ill holiday"

case $1 in
    teams) Value="team"
    ;;
    depts) Value="hwde swde qcde"
    ;;
esac

for val in $Value; do
    for act in $Activities; do
        eval "${val}_${act}=0"
    done
done
}

sumperprojbyuser () {

echo "Month: $1" > accountant.txt

for i in $office1; do
    while read user project hours; do
        echo "$user $project $hours"
    done < <(mysql --login-path=<DB_LOGIN_PATH> -Nse  "use $DB; \
SELECT users.login, projects.name, sum(round(time_entries.hours,2)) \
     FROM users, time_entries INNER JOIN projects \
     ON time_entries.project_id = projects.id \
WHERE year(time_entries.spent_on) = '$year' \
     AND month(time_entries.spent_on) = '$1' \
     AND time_entries.user_id = users.id \
     AND users.login = '$i' \
GROUP BY projects.name;")
    echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
done
}

pm_tl_report () {

for Person in $TLs; do

    spent_total $Person

    if [[ $total_time != *[[:digit:]]* ]]; then
        total_time="<b>zero</b>"
    fi

    if [ -n "$Month" -a $(echo $total_time | awk '{printf "%.0f\n", $1}') -lt "131" ]; then
        echo -e "<b><font color=\"red\">$(echo $Person | tr [:lower:] [:upper:]) spent $total_time hours.</font></b> Details are:\n<br>" >> alireport.html
        else
        echo -e "$(echo $Person | tr [:lower:] [:upper:]) spent $total_time hours. Details are:\n<br>" >> alireport.html
    fi

    if [ "$total_time" = "<b>zero</b>" ]; then
        echo -e "Unfortunately there are no details.\n<br><br>" >> alireport.html
        continue
    fi

    spent_effort $Person

    echo -e "Project effort is $(echo "$project_time 100 $total_time" | awk '{printf "%.0f\n", ($1 * $2) / $3}')%.\n<br>" >> alireport.html
    echo -e "Sales effort is $(echo "$sales_time 100 $total_time" | awk '{printf "%.0f\n", ($1 * $2) / $3}')%.\n<br>" >> alireport.html
    echo -e "Other effort is $(echo "$total_time $project_time $sales_time 100 $total_time" | awk '{printf "%.0f\n", (($1 - $2 - $3) * $4) / $5}')%.\n<br>" >> alireport.html
    echo -e "$(spent_details $Person)\n<br>" >> alireport.html
done

sed -i 's/<TABLE BORDER=1>/<table border="1" style="border-collapse: collapse;" cellpadding="3">/g' alireport.html
}

spent_total () {

TL="$1"
total_time=

while read user hours; do
  total_time=$hours
done < <(mysql --login-path=<DB_LOGIN_PATH> -Ns -e  "use $DB; \
SELECT users.login, SUM(ROUND(time_entries.hours, 2)) \
      FROM time_entries, users \
WHERE users.login LIKE '$TL' \
      AND $Interval1 \
      AND $Interval2 \
      AND time_entries.user_id = users.id \
GROUP BY users.login;")
}

spent_effort () {

TL="$1"
project_time="0"
sales_time="0"

while IFS=$'\t' read proj time; do
  [[ "$proj" =~ ^[0-9].* ]] && project_time=$(echo $project_time $time | awk '{print $1 + $2}')
  [[ "$proj" =~ ^Sales.* ]] && sales_time=$(echo $sales_time $time | awk '{print $1 + $2}')
done < <(mysql --login-path=<DB_LOGIN_PATH> -Ne  "use $DB; \
SELECT projects.name AS Projects, SUM(ROUND(time_entries.hours, 2)) \
      FROM users, time_entries INNER JOIN projects \
	  ON time_entries.project_id = projects.id \
WHERE users.login LIKE '$TL' \
      AND $Interval1 \
      AND $Interval2 \
      AND time_entries.user_id = users.id \
GROUP BY projects.name;")
}

spent_details () {

TL="$1"

mysql --login-path=<DB_LOGIN_PATH> -He  "use $DB; \
SELECT projects.name AS Projects, SUM(ROUND(time_entries.hours, 2)) AS Hours \
      FROM users, time_entries INNER JOIN projects \
      ON time_entries.project_id = projects.id \
WHERE users.login LIKE '$TL' \
      AND $Interval1 \
      AND $Interval2 \
      AND time_entries.user_id = users.id \
GROUP BY projects.name;"
}

weekly_spent_array_example () {
TL="$1"
list=""
i=0
declare -a array1
declare -a array2

while read user hours; do
  list="$list $user"
  array1+=($user)
  array2[i]="$hours"
  ((i++))
done < <(mysql --login-path=<DB_LOGIN_PATH> -Ns -e  "use $DB; \
SELECT users.login, SUM(ROUND(time_entries.hours, 2)) \
     FROM time_entries, users \
WHERE users.login LIKE $TL \
    AND time_entries.spent_on >= DATE(NOW()) - INTERVAL 7 DAY \
    AND time_entries.spent_on < CURDATE() \
    AND time_entries.user_id = users.id \
GROUP BY users.login;")

#echo "list: ${list# }"
#echo "array1: ${array1[@]}"
#echo "array2: ${array2[@]}"

for ((i=0; i<${#array1[@]}; i++)); do
  echo "$(echo ${array1[$i]} | tr [:lower:] [:upper:]) spent ${array2[$i]} hours"
done
}

total_monthly_hours () {

user_registered=$(mysql --login-path=<DB_LOGIN_PATH> -Ns -e "use <REDMINE_DB>; \
        SELECT IFNULL(SUM(ROUND(time_entries.hours, 2)), '0') \
            FROM time_entries, users \
        WHERE YEAR(time_entries.spent_on) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) \
            AND MONTH(time_entries.spent_on) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH) \
            AND time_entries.user_id = users.id \
            AND users.login = '$1';")

#user_registered=${user_registered:-0}
team_registered=$(echo $team_registered $user_registered | awk '{print $1 + $2}')
echo "Total registered hours: $user_registered<br>"
}

invoiceable () {

user_invoiced=0
user_noninvoiced=0
vacation=0

while IFS=$'\t' read parent_id proj time; do
  if [ "$i" != "office2" -o "$1" = "ago" -o "$1" = "ysu" ]; then
    [[ $parent_id != "NULL" ]] && ! [[ "$proj" =~ ^3[0-1]0[1-6].* ]] && \
      while IFS=$'\t' read parent_name; do
        [[ "$parent_name" =~ ^3[0-1]0[1-6].* ]] && \
        user_invoiced=$(echo $user_invoiced $time | awk '{print $1 + $2}')
      done < <(mysql --login-path=<DB_LOGIN_PATH> -Ne \
                "use <REDMINE_DB>; SELECT projects.name FROM projects \
                WHERE projects.id = '$parent_id';")

    [[ "$proj" =~ ^3[0-1]0[1-6].* ]] && \
    user_invoiced=$(echo $user_invoiced $time | awk '{print $1 + $2}')

    [[ "$proj" =~ ^Vacation.* ]] && \
    vacation=$(echo $vacation $time | awk '{print $1 + $2}')

  else

    [[ $parent_id != "NULL" ]] && \
  ! [[ "$proj" =~ ^320.* ]] || ! [[ "$proj" =~ ^300[56].* ]] && \
      while IFS=$'\t' read parent_name; do
        [[ "$parent_name" =~ ^320.* ]] || [[ "$parent_name" =~ ^300[56].* ]] && \
        user_invoiced=$(echo $user_invoiced $time | awk '{print $1 + $2}')
      done < <(mysql --login-path=<DB_LOGIN_PATH> -Ne \
                "use <REDMINE_DB>; SELECT projects.name FROM projects \
                WHERE projects.id = '$parent_id';")

    [[ "$proj" =~ ^320.* ]] || [[ "$proj" =~ ^300[56].* ]] && \
    user_invoiced=$(echo $user_invoiced $time | awk '{print $1 + $2}')

    #[[ "$proj" =~ ^Vacation.* ]] && vacation=$(echo $vacation $time | awk '{print $1 + $2}')

    [[ "$proj" = "Laboratory Maintenance" ]] && \
    user_noninvoiced=$(echo $user_noninvoiced $time | awk '{print $1 + $2}')
  fi
done < <(mysql --login-path=<DB_LOGIN_PATH> -Ne  "use <REDMINE_DB>; \
SELECT ANY_VALUE(projects.parent_id), projects.name, SUM(ROUND(time_entries.hours, 2)) \
      FROM users,
      time_entries INNER JOIN projects \
	ON time_entries.project_id = projects.id \
WHERE YEAR(time_entries.spent_on) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) \
    AND MONTH(time_entries.spent_on) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH) \
    AND time_entries.user_id = users.id \
    AND users.login = '$1' \
GROUP BY projects.name;")

team_invoiced=$(echo $team_invoiced $user_invoiced | awk '{print $1 + $2}')
echo "Invoiceable hours: $user_invoiced<br>"
#echo "Vacation hours: $vacation<br>"
}


noninvoiceable_projects () {

unset noninvoiceable_arr

noninvoiceable_parents=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
                "use <REDMINE_DB>; SELECT id FROM projects \
                WHERE parent_id is NULL \
                AND status = '1' \
                AND name LIKE '3007%' \
                UNION SELECT id FROM projects \
                WHERE status = '1' \
                AND (name = 'SW Department Activities' \
                    OR name = 'Education&learning' \
                    OR name = 'HW Department Activities') \
                ORDER BY id;")

for i in $noninvoiceable_parents; do
   noninvoiceable_arr+=(`mysql --login-path=<DB_LOGIN_PATH> -Nse \
                        "use <REDMINE_DB>; SELECT id FROM projects WHERE parent_id = '$i';"`)
done

noninvoiceable_arr+=($noninvoiceable_parents)
noninvoiceable_arr=(${noninvoiceable_arr[@]/%/,})
last=$((${#noninvoiceable_arr[@]} - 1))
noninvoiceable_arr[$last]=${noninvoiceable_arr[$last]%,}

}


noninvoiceable () {

user_noninvoiced_time=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
            "use <REDMINE_DB>; SELECT IFNULL(SUM(ROUND(time_entries.hours, 2)), '0') \
                FROM time_entries, users \
            WHERE YEAR(time_entries.spent_on) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) \
                AND MONTH(time_entries.spent_on) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH) \
                AND time_entries.user_id = users.id \
                AND users.login = '$1' \
                AND time_entries.project_id IN (`echo ${noninvoiceable_arr[@]}`);")

user_noninvoiced=$(echo $user_noninvoiced $user_noninvoiced_time | awk '{print $1 + $2}')
team_noninvoiced=$(echo $team_noninvoiced $user_noninvoiced | awk '{print $1 + $2}')
echo "Non-invoiceable RD/QA: $user_noninvoiced<br>"
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


nominalworkhoursperson () {

case $j in
  ali|ose|tiv|ppo|oko) holiday ua
                       user_nominal=$((($WorkDays - $hol) * 8))
  ;;
  #ppo) holiday ua
  #     user_nominal=$((($WorkDays - $hol) * 7))
  #;;
  isa|jes|jho|nmj|hjc|cme) holiday dk
                           user_nominal=$(echo "$WorkDays $hol 7.4" | awk '{print ($1 - $2) * $3}')
  ;;
esac

#echo "User nominal: $user_nominal hours."
}

nominalworkhours () {

case $i in
  office1)  holiday ua

           if [ $j = ato ]; then
              user_nominal=$((($WorkDays - $hol) * 6))
              elif [ $j = yly ]; then
              user_nominal=$user_registered
              elif [ $j = voi ]; then
              user_nominal=$user_registered
              elif [ $j = ssh ]; then
              user_nominal=$((($WorkDays - $hol) * 4))
              else
              user_nominal=$((($WorkDays - $hol) * 8))
           fi

  ;;
  office2)  holiday ua

           if [ $j = mta ]; then
              user_nominal=$((($WorkDays - $hol) * 4))
              else
              user_nominal=$((($WorkDays - $hol) * 8))
           fi
  ;;
  office3|office4) holiday dk
           user_nominal=$(echo "$WorkDays $hol 7.4" | awk '{print ($1 - $2) * $3}')

           if [ $j = "oto" ]; then
                holiday ua
                user_nominal=$((($WorkDays - $hol) * 8))
           fi
  ;;
  ADMIN)   #user_nominal="depending on user"
           nominalworkhoursperson
  ;;
esac

echo "NominalWorkingHours (without holidays): $user_nominal hours<br>"
}

nominalworkdays () {

if [ $user_registered = 0 ]; then
    user_nominal=0
    echo "NominalWorkingHours: $user_nominal<br>"
    return
fi

WorkDays=$WorkDaysTotal
StartWorkDay=
FinishWorkDay=

for DateToCompare in "Start day" "Finish day"; do

        DateValue=$(mysql --login-path=<DB_LOGIN_PATH> -Ns -e \
                    "use <REDMINE_DB>; SELECT value FROM custom_values \
                    WHERE customized_id = (SELECT id FROM users WHERE login = '$1') \
                    AND custom_field_id = (SELECT id FROM custom_fields WHERE name = '$DateToCompare')")

        #echo "DateValue: $DateValue"

        if [ -n "$DateValue" ]; then
            DateValueYear=$(date -d $DateValue '+%Y')

            #echo "DateValueYear: $DateValueYear"

            else
            continue
        fi

        if [ $YearToCompare = $DateValueYear ]; then
             DateValueMonth=$(date -d $DateValue '+%-m')

             #echo "DateValueMonth: $DateValueMonth"

             else
             continue
        fi

        if [ "$PastMonth" = "$DateValueMonth" ]; then
            echo "$DateToCompare - $DateValue<br>"
            DateValueDay=$(date -d $DateValue '+%-d')

            #echo "DateValueDay: $DateValueDay"

            else
            continue
        fi

        WorkDaysValue=$(cal -m $(date +%m -d 'last month') $YearToCompare \
                       | tail -n +3 | cut -c1-14 | \grep "\S" \
                       | fmt -w 1 | sort -n | sed "s/^[ \t]*//" | grep -wn $DateValueDay | awk -F: '{print $1}')

        #echo "WorkDaysValue: $WorkDaysValue"

        case ${DateToCompare% day} in
            Start) echo "Working days are from the Start day [$DateValueDay] till the end of month.<br>"
                   WorkDays=$((WorkDaysTotal - WorkDaysValue + 1))

                   #echo "WorkDays: $WorkDays"

                   StartWorkDay=$WorkDaysValue
            ;;
            Finish) echo "Workings days are from the start of month till Finish day [$DateValueDay].<br>"

                    WorkDays=$WorkDaysValue

                    #echo "WorkDays: $WorkDays"

                    FinishWorkDay=$WorkDaysValue
            ;;
        esac
done

if [ -n "$StartWorkDay" ] && [ -n "$FinishWorkDay" ]; then
    WorkDays=$((FinishWorkDay - StartWorkDay + 1))
fi

echo "NominalWorkingDays (with holidays): $WorkDays days<br>"
nominalworkhours
}

sales_projects () {
unset sales_arr

sales_parent=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
            "use <REDMINE_DB>; SELECT id FROM projects WHERE name = 'Sales work';")

sales_arr=(`mysql --login-path=<DB_LOGIN_PATH> -Nse \
        "use <REDMINE_DB>; SELECT id FROM projects WHERE parent_id = '$sales_parent';"`)

sales_arr+=($sales_parent)
sales_arr=(${sales_arr[@]/%/,})
last=$((${#sales_arr[@]} - 1))
sales_arr[$last]=${sales_arr[$last]%,}
}

sales_hours () {
#user_sales=0

user_sales=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
            "use <REDMINE_DB>; SELECT IFNULL(SUM(ROUND(time_entries.hours, 2)), '0') \
                FROM time_entries, users \
            WHERE YEAR(time_entries.spent_on) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) \
                AND MONTH(time_entries.spent_on) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH) \
                AND time_entries.user_id = users.id \
                AND users.login = '$1' \
                AND time_entries.project_id IN (`echo ${sales_arr[@]}`);")

#[[ $user_sales == NULL ]] && user_sales=0
team_sales=$(echo $team_sales $user_sales | awk '{print $1 + $2}')
echo "Sales work: $user_sales<br>"
}

meeting_projects () {
unset meeting_arr

meeting_parents=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
                "use <REDMINE_DB>; SELECT id FROM projects \
                WHERE parent_id is NULL \
                AND status = '1' \
                AND (name LIKE '3001%' OR name LIKE '3002%' OR name LIKE '3003%' OR name LIKE '3004%' \
                    OR name LIKE '3005%' OR name LIKE '3006%' OR name LIKE '3007%' OR name LIKE '320%') \
                UNION SELECT id FROM projects \
                WHERE status = '1' \
                AND (name = 'Project Management Office' OR name = 'Sales work' OR name = 'Laboratory Maintenance' ) \
                ORDER BY id;")

for i in $meeting_parents; do
   meeting_arr+=(`mysql --login-path=<DB_LOGIN_PATH> -Nse \
                "use <REDMINE_DB>; SELECT id FROM projects WHERE parent_id = '$i';"`)
done

meeting_arr+=($meeting_parents)
meeting_arr=(${meeting_arr[@]/%/,})
meeting_arr+=(${sales_arr[@]})
last=$((${#meeting_arr[@]} - 1))
lastValue=${meeting_arr[$last]},
meeting_arr[$last]=$lastValue
meeting_arr+=(${noninvoiceable_arr[@]})

}

meeting_hours () {

user_meeting=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
            "use <REDMINE_DB>; SELECT IFNULL(SUM(ROUND(time_entries.hours, 2)), '0') \
                FROM time_entries, users \
            WHERE activity_id IN (SELECT id FROM enumerations WHERE name = 'Meetings') \
                AND YEAR(time_entries.spent_on) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) \
                AND MONTH(time_entries.spent_on) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH) \
                AND time_entries.user_id = users.id \
                AND users.login = '$1' \
                AND time_entries.project_id NOT IN (`echo ${meeting_arr[@]}`);")

#[[ $user_meeting == NULL ]] && user_meeting=0
team_meeting=$(echo $team_meeting $user_meeting | awk '{print $1 + $2}')
echo "Meetings: $user_meeting<br>"
#for i in ${arr[@]}; do echo $i; done | wc -l
}


pmo_hours () {
user_pmo=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
        "use <REDMINE_DB>; SELECT IFNULL(SUM(ROUND(time_entries.hours, 2)), '0') \
             FROM time_entries, users \
         WHERE time_entries.project_id = (SELECT id FROM projects \
                                          WHERE name = 'Project Management Office') \
             AND YEAR(time_entries.spent_on) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) \
             AND MONTH(time_entries.spent_on) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH) \
             AND time_entries.user_id = users.id \
             AND users.login = '$1';")

team_pmo=$(echo $team_pmo $user_pmo | awk '{print $1 + $2}')
echo "PMO: $user_pmo<br>"
}


ill_hours () {
user_ill=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
        "use <REDMINE_DB>; SELECT IFNULL(SUM(ROUND(time_entries.hours, 2)), '0') \
             FROM time_entries, users \
         WHERE activity_id IN (SELECT id FROM enumerations WHERE name LIKE '%ill%') \
             AND YEAR(time_entries.spent_on) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) \
             AND MONTH(time_entries.spent_on) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH) \
             AND time_entries.user_id = users.id \
             AND users.login = '$1';")

#[[ $user_ill == NULL ]] && user_ill=0
team_ill=$(echo $team_ill $user_ill | awk '{print $1 + $2}')
echo "Ill: $user_ill<br>"
}



holiday_hours () {
user_holiday=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
        "use <REDMINE_DB>; SELECT IFNULL(SUM(ROUND(time_entries.hours, 2)), '0') \
             FROM time_entries, users \
         WHERE activity_id IN \
            (SELECT id FROM enumerations WHERE (name LIKE '%day off%' OR name LIKE '%holiday%' OR name LIKE 'Vacation/Day-Off') \
             AND id NOT IN (SELECT id FROM enumerations WHERE name LIKE '%ill%')) \
             AND YEAR(time_entries.spent_on) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) \
             AND MONTH(time_entries.spent_on) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH) \
             AND time_entries.user_id = users.id \
             AND users.login = '$1';")

#[[ $user_holiday == NULL ]] && user_holiday=0

if [ "$1" = "ssh" ] && [ "${user_holiday%.*}" -ne 0 ]; then

    user_holiday=$(echo $user_holiday 2 | awk '{print $1 / $2}')

    user_registered=$(echo $user_registered $user_holiday | awk '{print $1 - $2}')

    echo "Total registered hours (corrected): $user_registered<br>"

fi

team_holiday=$(echo $team_holiday $user_holiday | awk '{print $1 + $2}')
echo "Holidays: $user_holiday<br>"
}


user_stats () {
echo "<b>$(echo $j | tr [:lower:] [:upper:])</b>:<br>"

total_monthly_hours $j
nominalworkdays $j
invoiceable $j
noninvoiceable $j
sales_hours $j
meeting_hours $j
pmo_hours $j
ill_hours $j
holiday_hours $j

if [ $user_nominal = 0 ]; then
    user_prod=0
    else
    user_prod=$(echo "$user_registered $user_holiday $user_nominal" \
                | awk '{printf "%.0f\n", (($1 - $2) / ($3 - $2)) * 100}')
fi

echo "Productivity: ${user_prod}%<br>"

user_eff=$(echo "$user_invoiced $user_registered $user_holiday" \
          | awk '{if ($1>0 && $2>0) printf "%.0f\n", ($1 / ($2 - $3)) * 100; else print "0"}')

echo "Efficiency: ${user_eff}%<br>"

user_pe=$(echo "$user_prod $user_eff" | awk '{printf "%.0f\n", ($1 * $2) / 100}')

echo "Prod*Eff: ${user_pe}%<br>"
echo "**********************************<br>"

team_nominal=$(calc $team_nominal+$user_nominal)

if echo "$SWDE" | grep -q $j; then
    swde_prod=$(calc $swde_prod+$user_prod)
    swde_eff=$(calc $swde_eff+$user_eff)
    swde_nominal=$(calc $swde_nominal+$user_nominal)
    swde_registered=$(calc $swde_registered+$user_registered)
    swde_invoiced=$(calc $swde_invoiced+$user_invoiced)
    swde_noninvoiced=$(calc $swde_noninvoiced+$user_noninvoiced)
    swde_sales=$(calc $swde_sales+$user_sales)
    swde_meeting=$(calc $swde_meeting+$user_meeting)
    swde_pmo=$(calc $swde_pmo+$user_pmo)
    swde_ill=$(calc $swde_ill+$user_ill)
    swde_holiday=$(calc $swde_holiday+$user_holiday)
  elif echo "$HWDE" | grep -q $j; then
    hwde_prod=$(calc $hwde_prod+$user_prod)
    hwde_eff=$(calc $hwde_eff+$user_eff)
    hwde_nominal=$(calc $hwde_nominal+$user_nominal)
    hwde_registered=$(calc $hwde_registered+$user_registered)
    hwde_invoiced=$(calc $hwde_invoiced+$user_invoiced)
    hwde_noninvoiced=$(calc $hwde_noninvoiced+$user_noninvoiced)
    hwde_sales=$(calc $hwde_sales+$user_sales)
    hwde_meeting=$(calc $hwde_meeting+$user_meeting)
    hwde_pmo=$(calc $hwde_pmo+$user_pmo)
    hwde_ill=$(calc $hwde_ill+$user_ill)
    hwde_holiday=$(calc $hwde_holiday+$user_holiday)
  elif echo "$QCDE" | grep -q $j; then
    qcde_prod=$(calc $qcde_prod+$user_prod)
    qcde_eff=$(calc $qcde_eff+$user_eff)
    qcde_nominal=$(calc $qcde_nominal+$user_nominal)
    qcde_registered=$(calc $qcde_registered+$user_registered)
    qcde_invoiced=$(calc $qcde_invoiced+$user_invoiced)
    qcde_noninvoiced=$(calc $qcde_noninvoiced+$user_noninvoiced)
    qcde_sales=$(calc $qcde_sales+$user_sales)
    qcde_meeting=$(calc $qcde_meeting+$user_meeting)
    qcde_pmo=$(calc $qcde_pmo+$user_pmo)
    qcde_ill=$(calc $qcde_ill+$user_ill)
    qcde_holiday=$(calc $qcde_holiday+$user_holiday)
fi

if [ $UpdateMysql ]; then

    echo "INSERT INTO users (date,dept,user,prod,eff,pe,nominal,registered,invoiced,noninvoiced,sales,meeting,pmo,ill,holiday,other) \
          VALUES ('$Date', '$i', '$j', '$user_prod', '$user_eff', '$user_pe', '$user_nominal', '$user_registered', \
                  '$user_invoiced', '$user_noninvoiced', '$user_sales', '$user_meeting', '$user_pmo', '$user_ill', '$user_holiday', \
                  ROUND((registered-invoiced-noninvoiced-sales-meeting-pmo-ill-holiday), 2)) \
          ON DUPLICATE KEY UPDATE \
          prod=VALUES(prod), eff=VALUES(eff), pe=VALUES(pe), nominal=VALUES(nominal) ,registered=VALUES(registered), \
          invoiced=VALUES(invoiced), noninvoiced=VALUES(noninvoiced), sales=VALUES(sales), meeting=VALUES(meeting), \
          pmo=VALUES(pmo), ill=VALUES(ill), holiday=VALUES(holiday), other=VALUES(other);" \
          | mysql effort

fi
}

team_stats () {
echo "<b>Team $i total</b>:<br>"
echo "Nominal work hours: $team_nominal<br>"
echo "Total registered hours: $team_registered<br>"
team_prod=$(echo "$team_registered $team_nominal" | awk '{printf "%.0f\n", ($1 / $2) * 100}')
echo "Productivity: ${team_prod}%<br>"
echo "Invoiceable hours: $team_invoiced<br>"
echo "Non-invoiceable RD/QA: $team_noninvoiced<br>"
echo "Vacation hours: $team_holiday<br>"
team_eff=$(echo "$team_invoiced $team_registered $team_holiday" \
          | awk '{if ($1>0 && $2>0) printf "%.0f\n", ($1 / ($2 - $3)) * 100; else print "0"}')
echo "Efficiency: ${team_eff}%<br>"
team_pe=$(echo "$team_prod $team_eff" | awk '{printf "%.0f\n", ($1 * $2) / 100}')
echo "Prod*Eff: $team_pe%<br>"
echo "===============================<br>"

if [ $UpdateMysql ]; then

    echo "INSERT INTO teams (date,team,prod,eff,pe,nominal,registered,invoiced,noninvoiced,sales,meeting,pmo,ill,holiday,other) \
          VALUES ('$Date', '$i', '$team_prod', '$team_eff', '$team_pe', '$team_nominal', '$team_registered', \
                  '$team_invoiced', '$team_noninvoiced', '$team_sales', '$team_meeting', '$team_pmo', '$team_ill', '$team_holiday', \
                  ROUND((registered-invoiced-noninvoiced-sales-meeting-pmo-ill-holiday), 2)) \
          ON DUPLICATE KEY UPDATE \
          prod=VALUES(prod), eff=VALUES(eff), pe=VALUES(pe), nominal=VALUES(nominal), registered=VALUES(registered), \
          invoiced=VALUES(invoiced), noninvoiced=VALUES(noninvoiced), sales=VALUES(sales), meeting=VALUES(meeting), \
          pmo=VALUES(pmo), ill=VALUES(ill), holiday=VALUES(holiday), other=VALUES(other);" \
          | mysql effort

fi
}

dept_stats () {

for department in swde hwde qcde; do
    dept_upper=$(echo $department | tr [:lower:] [:upper:])
    echo "<b>$dept_upper</b>:<br>"


    ################ OLD CODE #################################################
    ##eval dept_up="$"$dept_upper
    ##dept_count=$(echo $dept_up | wc -w)

    #dept_count=$(mysql --login-path=<DB_LOGIN_PATH> -Ne  "use effort; \
    #            SELECT num FROM counter WHERE dept = '$department' \
    #            AND YEAR(date) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) \
    #            AND MONTH(date) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH);")


    #eval dept_p="$"${department}_prod
    #dept_prod=$(echo "$dept_p $dept_count" | awk '{printf "%.0f\n", $1 / $2}')
    #echo "Productivity: ${dept_prod}%<br>"

    #eval dept_e="$"${department}_eff
    #dept_eff=$(echo "$dept_e $dept_count" | awk '{printf "%.0f\n", $1 / $2}')
    #echo "Efficiency: ${dept_eff}%<br>"

    #dept_pe=$(echo "$dept_prod $dept_eff" | awk '{printf "%.0f\n", ($1 * $2) / 100}')
    #echo "Prod*Eff: $dept_pe%<br>"


    eval dept_nominal="$"${department}_nominal
    eval dept_registered="$"${department}_registered
    eval dept_invoiced="$"${department}_invoiced
    eval dept_noninvoiced="$"${department}_noninvoiced
    eval dept_sales="$"${department}_sales
    eval dept_meeting="$"${department}_meeting
    eval dept_pmo="$"${department}_pmo
    eval dept_ill="$"${department}_ill
    eval dept_holiday="$"${department}_holiday

    ######################### NEW CODE ############################################

    dept_prod=$(echo "$dept_registered $dept_nominal" \
                | awk '{if ($1>0) printf "%.0f\n", ($1 / $2) * 100; else print "0"}')
    echo "Productivity: ${dept_prod}%<br>"

    dept_eff=$(echo "$dept_invoiced $dept_registered $dept_holiday" \
            | awk '{if ($1>0 && $2>0) printf "%.0f\n", ($1 / ($2 - $3)) * 100; else print "0"}')
    echo "Efficiency: ${dept_eff}%<br>"

    dept_pe=$(echo "$dept_prod $dept_eff" | awk '{printf "%.0f\n", ($1 * $2) / 100}')
    echo "Prod*Eff: $dept_pe%<br>"


    ###############################################################################
    echo "<br>"

    if [ $UpdateMysql ]; then

        echo "INSERT INTO depts (date,dept,prod,eff,pe,nominal,registered,invoiced,noninvoiced,sales,meeting,pmo,ill,holiday,other) \
              VALUES ('$Date', '$department', '$dept_prod', '$dept_eff', '$dept_pe', '$dept_nominal', '$dept_registered', \
                      '$dept_invoiced', '$dept_noninvoiced', '$dept_sales', '$dept_meeting', '$dept_pmo', '$dept_ill', '$dept_holiday', \
                      ROUND((registered-invoiced-noninvoiced-sales-meeting-pmo-ill-holiday), 2)) \
              ON DUPLICATE KEY UPDATE \
              prod=VALUES(prod), eff=VALUES(eff), pe=VALUES(pe), nominal=VALUES(nominal), registered=VALUES(registered), \
              invoiced=VALUES(invoiced), noninvoiced=VALUES(noninvoiced), sales=VALUES(sales), meeting=VALUES(meeting), \
              pmo=VALUES(pmo), ill=VALUES(ill), holiday=VALUES(holiday), other=VALUES(other);" \
              | mysql effort

    fi
done
}

main () {
init_vars depts
sales_projects
noninvoiceable_projects
meeting_projects

for i in $Teams; do
  eval y="$"$i
  init_vars teams
  echo "-----------Statistics for <b>$i</b> team.------------<br>"
    for j in $y; do
      user_stats

      #exit 11

    done
  team_stats
done
dept_stats
}
