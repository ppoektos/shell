#!/bin/bash
SHELL=/bin/bash
Path="/root/report"
File="/var/www/twiki/data/Main/LunchOrdering.txt"
Tmp="/tmp/lunchtmp"
Today=`date +%a`
Week=`date --date= +%V_%Y`
NextDayFull=`date --date="next day" +%A,\ %d/%m/%Y`
NextDayFullMysql=`date --date="next day" +%Y-%m-%d`
NextDayShort=`date --date="next day" +%A`
ChoiceYes="0"
ChoiceNo="0"
PersonYes=""
PersonNo=""
SendOrder=true
ConnectionString="mysql -u <DB_USER> -p<DB_PASSWORD> -h <DB_HOST> lunchorder"

func () {

if [ "$Today" = "Fri" ]; then
    NextDayFull=`date --date="+3 day" +%A,\ %d/%m/%Y`
    NextDayFullMysql=`date --date="+3 day" +%Y-%m-%d`
    NextDayShort=`date --date="+3 day" +%A`
    Week=`date --date="+ 1 week" +%V_%Y`
fi

Column="$1"

ChoiceArray=(`sed '/^| /!d; /^| \*/d' $File | awk -v day="$Column" -F"|" '{ print $day }'`)
PersonArray=(`sed '/^| /!d; /^| \*/d' $File | awk -F" " '{print$2}'`)

for ((i=0; i<${#ChoiceArray[@]}; i++))
   do
    if [ ${ChoiceArray[$i]} = "yes" ]; then
        ChoiceYes=`expr $ChoiceYes + 1`
        PersonYes="$PersonYes ${PersonArray[$i]},"
            if ! echo "INSERT INTO orders (user,order_date) VALUES ('${PersonArray[$i]}', '$NextDayFullMysql');" \
                | $ConnectionString; then
                echo "${PersonArray[$i]} $NextDayFullMysql" >> $Path/deferred
            fi
    elif [ ${ChoiceArray[$i]} = "no" ]; then
        ChoiceNo=`expr $ChoiceNo + 1`
        PersonNo="$PersonNo ${PersonArray[$i]}"
    fi
    sleep 1
done

case $ChoiceYes in
    0)  SendOrder=false
    ;;
    1)  SendOrder=false
        echo "DELETE FROM lunchorder.orders WHERE orders.order_date = '$NextDayFullMysql';" \
             | $ConnectionString
    ;;
    2)  ChoiceYes=3
        PersonYes="$PersonYes VirtualPerson,"
        if ! echo "INSERT INTO orders (user,order_date) VALUES ('VirtualPerson', '$NextDayFullMysql');" \
                | $ConnectionString; then
                echo "VirtualPerson $NextDayFullMysql" >> $Path/deferred
        fi
    ;;
esac

echo -e "Who made order: ${PersonYes%%,} \n <CONFLUENCE_URL>" > $Path/details

if $SendOrder; then

    echo "UPDATE orders, users SET orders.group_id = '1' WHERE orders.user = users.name and users.group = '1';
          UPDATE orders, users SET orders.group_id = '2' WHERE orders.user = users.name and users.group = '2';
          UPDATE orders SET orders.group_id = '5' WHERE orders.group_id = '3' AND orders.user LIKE '%Company1_%';
          UPDATE orders SET orders.group_id = '6' WHERE orders.group_id = '3' AND orders.user LIKE '%Company3_%';
          UPDATE orders SET orders.group_id = '4' WHERE orders.group_id = '3' AND orders.user LIKE '%Company2_%';" \
    | $ConnectionString

    echo "List of person, who select Yes for ordering for $NextDayFull: $PersonYes" >> $Path/dayperson

    mutt -s "Lunch order for $NextDayFull: $ChoiceYes persons." -- <CATERING_EMAIL> < /root/lunchorderbody.txt
    sleep 5
    mutt -s "Lunch order for $NextDayFull: $ChoiceYes persons." -- <OFFICE_MANAGER_EMAIL> < $Path/details

    else

    mutt -s "Lunch order for $NextDayFull: $ChoiceYes persons. Order is not sent to the catering service." -- <OFFICE_MANAGER_EMAIL> < $Path/details

fi

awk -v day="$Column" -F"|" 'BEGIN { OFS="|" } ($day == " yes ") { $day = " no " } { print $0 }' $File > $Tmp

mv $Tmp $File && chown apache:apache $File

echo "$NextDayShort: $PersonYes" >> $Path/Week_$Week
echo "$NextDayShort total: $ChoiceYes" >> $Path/Week_$Week

if [ -s $Path/deferred ]; then
  mutt -s "Lunch order: deferred action occurred." -- <ADMIN_EMAIL> < $Path/deferred
fi
}

if [ -s $Path/deferred ]; then

    echo | mutt -s "Attempt to fix deferred action." -- <ADMIN_EMAIL>

    while read -r user date; do
        if echo "INSERT INTO orders (user,order_date) VALUES ('$user', '$date');" \
            | $ConnectionString; then
            sed -i '1d' $Path/deferred
        fi
    done < $Path/deferred
fi

case $Today in
  Mon) func 4
  ;;
  Tue) func 5
  ;;
  Wed) func 6
  ;;
  Thu) func 7
awk -Ftotal:\  '{tot+=$2}; END {print "Total week orders: " tot}' $Path/Week_$Week >> $Path/Week_$Week
  ;;
  Fri) func 3
  ;;
esac

exit 0
