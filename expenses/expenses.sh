#!/bin/bash
dts=`date +%Y-%m-%d`
File="/var/www/twiki/data/Main/OfficeExpenses.txt"
Insert=0
Update=0
ConnectionString="mysql --login-path=<DB_LOGIN_PATH>"


check_mysql () {
c=1
while ! $ConnectionString -e "use expenses;" ; do
    echo "no connection to mysql"
    mutt -s "Expenses can't connect to mysql. # $c." -- <ADMIN_EMAIL> <<< $(echo "Notification from $1 part")
    [[ $c -eq 6 ]] && exit 1
    sleep 3600
    ((c++))
done
}


if sed '/^| /!d; /^| \*/d' $File | grep -q "|" ; then
  Update=1
fi


if [ "$(date +%d)" = "01" ]; then
  Insert=1
fi


if [ $Insert -eq 1 ]; then
  echo "New month is started. Balance should be inserted in exp."

  ln=$(sed -n '/{format=/=' $File)

  sed -i "${ln}c\%EDITTABLE{format=\"| date, 15, ${dts}, %Y-%m-%d | select, 1, office1, office2 | select, 1, Administrative, Project, Office, Travel, Lab, Trial_salary, Deposit |  text, 30 |  text, 3 |  text, 10  | select, 1, No, Yes | text , 10 |\" }%" $File

  check_mysql balance

  echo "INSERT INTO main (expense_date) VALUES ('$dts');" \
        | $ConnectionString expenses


  for i in office1 office2; do

    lm=`date +%m -d 'last month'`

    if [ $lm -eq 12 ]; then
        year=`date +%Y -d 'last year'`
        else
        year=`date +%Y`
    fi

    echo "INSERT INTO exp (date,branch,ExpType,money) \
            VALUES ('$dts', '$i', 'Balance', \
            (SELECT prev_bal + prev_deposit - prev_expenses \
            from (select CURTIME() as a, \
            (SELECT money FROM exp WHERE branch = '$i' AND month(date) = '$lm' AND year(date) = '$year' AND ExpType = 'Balance') as prev_bal, \
            (SELECT IFNULL(sum(money), 0) FROM exp WHERE branch = '$i' AND month(Date) = '$lm' AND year(date) = '$year' AND ExpType = 'Deposit') as prev_deposit, \
            (SELECT IFNULL(sum(money), 0) FROM exp WHERE branch = '$i' AND month(Date) = '$lm' AND year(date) = '$year' AND ExpType NOT IN ('Deposit','Balance')) as prev_expenses) d));" \
            | $ConnectionString expenses

    echo "UPDATE main SET ${i}_bal = (SELECT money FROM exp WHERE branch = '$i' \
                                      AND date = '$dts' \
                                      AND ExpType = 'Balance') \
          WHERE expense_date = '$dts';" \
          | $ConnectionString expenses

  done
fi


# set comment for manual update
# : <<'END'

[[ $Update = 0 ]] && echo "No expenses to update" && exit 0

check_mysql process

cp $File /root/expenses/$dts.txt

while read line; do
  Date=$(echo $line | awk -F"|" '{print $2}')
  Office=$(echo $line | awk -F"|" '{print $3}')
  Type=$(echo $line | awk -F"|" '{print $4}')
  Desc=$(echo $line | awk -F"|" '{print $5}' | sed "s/'/\\\'/g" | sed 's/"/\\\"/g')
  Person=$(echo $line | awk -F"|" '{print $6}')
  Amount=$(echo $line | awk -F"|" '{print $7}')
  Checked=$(echo $line | awk -F"|" '{print $8}')

  months+=($(echo $Date | awk -F"-" '{print $2}'))
  years+=($(echo $Date | awk -F"-" '{print $1}'))
  offices+=($Office)

  if [ "$Checked" = "Yes" ]; then
    Project=$(echo $line | awk -F"|" '{print $9}')
    echo "INSERT INTO exp (date,branch,ExpType,description,resp,money,ProjectSpecified,ProjectNumber) \
          VALUES ('$Date', '$Office', '$Type', '${Desc:-blank}', '$Person', '$Amount', '1', '$Project');" \
         | $ConnectionString expenses
    else
    echo "INSERT INTO exp (date,branch,ExpType,description,resp,money) \
          VALUES ('$Date', '$Office', '$Type', '${Desc:-blank}', '$Person', '$Amount');" \
         | $ConnectionString expenses
  fi
done < <(sed '/^| /!d; /^| \*/d; s/| /|/g; s/ |/|/g' $File)

sed -i '/^| 2/d' $File

offices=$(printf "%s\n" ${offices[@]} | sort -u)
years=($(printf "%s\n" ${years[@]} | sort -u))
year_start=${years[0]}
months=($(printf "%s\n" ${months[@]} | sort -u))
months=(${months[@]#0})
month_start=${months[0]}
month_temp=$month_start

month_current=$(date +%-m)
year_current=`date +%Y`


# END


update_exp () {
echo "UPDATE main set ${1}_exp = \
      (SELECT IFNULL(sum(money), 0) FROM exp WHERE branch = '$1' \
      AND month(date) = '$2' AND year(date) = '$3' AND ExpType NOT IN ('Deposit','Balance')) \
      WHERE month(expense_date) = '$2' AND year(expense_date) = '$3';" | $ConnectionString expenses
}

update_cash () {
echo "UPDATE main set ${1}_cash = \
      (SELECT IFNULL(sum(money), 0) FROM exp WHERE branch = '$1' \
      AND month(date) = '$2' AND year(date) = '$3' AND ExpType = 'Deposit') \
      WHERE month(expense_date) = '$2' AND year(expense_date) = '$3';" | $ConnectionString expenses
}

update_balance () {
office=$1
month=$(date +%-m --date="$3-$2-14 -1 month")
year=$(date +%Y --date="$3-$2-14 -1 month")

id=$($ConnectionString -Ns -e \
     "USE expenses; SELECT id FROM exp WHERE ExpType = 'Balance' \
      AND branch = '$office' AND month(date) = '$2' AND year(date) = '$3';")

newBal=$($ConnectionString -Ns -e \
         "use expenses; SELECT prev_bal + prev_deposit - prev_expenses \
            from (select CURTIME() as a, \
            (SELECT money FROM exp WHERE branch = '$office' AND ExpType = 'Balance' AND month(date) = '$month' AND year(date) = '$year') as prev_bal, \
            (SELECT IFNULL(sum(money), 0) FROM exp WHERE branch = '$office' AND ExpType = 'Deposit' AND month(date) = '$month' AND year(date) = '$year') as prev_deposit, \
            (SELECT IFNULL(sum(money), 0) FROM exp WHERE branch = '$office' AND ExpType NOT IN ('Deposit','Balance') AND month(date) = '$month' AND year(date) = '$year') as prev_expenses) d;")

            echo "balance for office $1 for month $2 year $3 is $newBal. Id_balance is $id."

echo "update main set ${office}_bal = '$newBal' where month(expense_date) = '$2' AND year(expense_date) = '$3';" \
| $ConnectionString expenses

echo "update exp set money = '$newBal' where id = '$id';" \
| $ConnectionString expenses
}

: <<'END'

offices="office1"
year_start=2019
month_start=11
month_temp=$month_start
month_current=12
year_current=2019

END

for o in $offices; do
    for (( y=$year_start; y<=$year_current; y++ )); do
        for (( m=$month_start; m<=12; m++ )); do
            if [ $y -eq $year_current -a $m -gt $month_current ]; then
            break
            fi
            echo "$y-$m: $o"
            update_exp $o $m $y
            update_cash $o $m $y
            update_balance $o $m $y
        done
    month_start=1
    done
    month_start=$month_temp
done
