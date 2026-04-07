#!/bin/sh
MonthCurr=`date +%m`
PrevMonth=`date --date="last month" +%m`
MonthRep=`date --date="last month" +%B`

cd /tmp

if [ "$MonthCurr" = "01" ]; then
Year=`date --date="last year" +%Y`
    else
Year=`date +%Y`
fi

grep "$PrevMonth/$Year" /root/report/dayperson \
| grep Yes | awk -F, '{ print $3 }' > monthreport.txt

mutt -s "Lunch report for $MonthRep of $Year." -- <MANAGER1_EMAIL>,<MANAGER2_EMAIL>,<MANAGER3_EMAIL> < monthreport.txt
