#!/bin/bash
#set -x
cd /opt/notifications || exit 1
. ./effortfunc.sh

case "$1" in
  week)
        Interval1="time_entries.spent_on >= DATE(NOW()) - INTERVAL 7 DAY"
        Interval2="time_entries.spent_on < CURDATE()"

        echo -e "Report for week $(date --date="- 1 week" +%V).\n<br>\n<br>" > alireport.html

        pm_tl_report

        mutt -e 'set content_type="text/html"' -s "Weekly PM/TL group timesheet" -- <PM_EMAIL>,<MANAGER_EMAIL> < alireport.html

        sleep 5

        for i in $List; do
            if [ "$Dom" -eq "$i" ]; then
                Interval1="time_entries.spent_on >= DATE(NOW()) - INTERVAL 14 DAY"
                echo -e "Report for weeks $(date --date="- 2 week" +%V)-$(date --date="- 1 week" +%V).\n<br>\n<br>" > alireport.html
                pm_tl_report
                mutt -e 'set content_type="text/html"' -s "Bi-Weekly PM/TL group timesheet" -- <PM_EMAIL>,<MANAGER_EMAIL> < alireport.html
            fi
        done
  ;;
  month)
        Interval1="YEAR(time_entries.spent_on) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH)"
        Interval2="MONTH(time_entries.spent_on) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH)"
        Month=true

        echo -e "Report for month $(date --date="last month" +%B).\n<br>\n<br>" > alireport.html

        pm_tl_report

        mutt -e 'set content_type="text/html"' -s "Monthly PM/TL group timesheet" -- <PM_EMAIL>,<MANAGER_EMAIL> < alireport.html
  ;;
  total)
        WorkDaysTotal=$(cal -m $(date +%m -d 'last month') $YearToCompare \
                       | tail -n +3 | cut -c1-14 | wc -w)

        rm -f prod_eff.txt

        if [ x$2 = xsilent ]; then
            main #> /dev/null
            else
            main >> prod_eff.txt
            mutt -e 'set content_type="text/html"' -s "Productivity vs Efficiency for $(date --date="last month" +%B)" -- <ADMIN_EMAIL>,<NOTIFY_EMAIL> < prod_eff.txt
        fi
  ;;
  accountant)
        month=$(date +%m -d 'last month')
        #month="01 02"

        if [ $month -eq 12 ]; then
            year=$(date +%Y -d 'last year')
            else
            year=$(date +%Y)
        fi

        for m in $month; do
            sumperprojbyuser $m >> accountant.txt
            mutt -s "Spent time by users in projects for month: $m." -a ./accountant.txt -- <ADMIN_EMAIL>,<ACCOUNTANT_EMAIL>,<MANAGER_EMAIL> < /opt/notifications/accountant.subj
        done
  ;;
  *) echo "Usage: `basename $0` [week | month | total [silent] | accountant] "
  ;;
esac
