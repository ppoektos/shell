#!/bin/bash

Users="sst smo ool spo okl ppo"
CurrentYear=$(date +%Y)
PastYear=$(date +%Y -d 'last year')
CurrentMonth=$(date +%-m)
PastMonth=$(date +%-m -d 'last month')
WorkDaysTotal=$(ncal -hMm$(date +%m -d 'last month') | grep -vE "^S|^ |^$" | sed "s/[[:alpha:]]//g" \
                | fmt -w 1 | sort -n | sed "s/^[ \t]*//" | wc -l)

if [ $CurrentMonth = 1 ]; then
    YearToCompare=$PastYear
    else
    YearToCompare=$CurrentYear
fi

for user in $Users; do

    echo $user:

    for DateToCompare in "Start day" "Finish day"; do

        DateValue=$(mysql --login-path=<DB_LOGIN_PATH> -Ns -e \
                    "use <REDMINE_DB>; SELECT value FROM custom_values \
                    WHERE customized_id = (SELECT id FROM users WHERE login = '$user') \
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
            #echo "It looks like $DateToCompare for $user affects NominalWorkingHours for month $PastMonth."

            echo "$DateToCompare - $DateValue"
            DateValueDay=$(date -d $DateValue '+%-d')
            else
            continue
        fi

        WorkDaysValue=$(ncal -hMm$(date +%m -d 'last month') | grep -vE "^S|^ |^$" | sed "s/[[:alpha:]]//g" \
                       | fmt -w 1 | sort -n | sed "s/^[ \t]*//" | grep -wn $DateValueDay | awk -F: '{print $1}')

        case ${DateToCompare% day} in
            Start) echo "Calculate working days from Start day [$DateValueDay] till end of month."
                   echo "NominalWorkingHours is $(((WorkDaysTotal - WorkDaysValue + 1) * 8))"
            ;;
            Finish) echo "Calculate workings days from the begining of month till Finish day [$DateValueDay]."
                    echo "NominalWorkingHours is $((WorkDaysValue * 8))"
            ;;
        esac

    done
    echo
done
