#!/bin/bash
CurrentWeek=$(date +%V)
Year=$(date +%Y)
i=1
while [ $i -le $CurrentWeek ]; do
    echo "Year $Year, week $i:"
    echo
    mysql --login-path=<DB_LOGIN_PATH> -Nse  "use lunchorder;
        SELECT order_date, user FROM orders
        WHERE week(order_date,7) = '$i'
        AND year(order_date) = '$Year'"

    EktosAndGuests=$(mysql --login-path=<DB_LOGIN_PATH> -Nse  "use lunchorder;
                    SELECT count(orders.user)
                    FROM orders, groups
                    WHERE orders.group_id = groups.id
                    AND groups.name IN ('<COMPANY_GROUP_1>', '<COMPANY_GROUP_2>')
                    AND week(order_date,7) = '$i'
                    AND year(order_date) = '$Year'")

    ReliasAndGuests=$(mysql --login-path=<DB_LOGIN_PATH> -Nse  "use lunchorder;
                    SELECT count(orders.user)
                    FROM orders, groups
                    WHERE orders.group_id = groups.id
                    AND groups.name IN ('relias', 'guest_relias')
                    AND week(order_date,7) = '$i'
                    AND year(order_date) = '$Year'")

    Cirkel=$(mysql --login-path=<DB_LOGIN_PATH> -Nse  "use lunchorder;
                    SELECT count(orders.user)
                    FROM orders, groups
                    WHERE orders.group_id = groups.id
                    AND groups.name =  'guest_cirkel'
                    AND week(order_date,7) = '$i'
                    AND year(order_date) = '$Year'")
    echo
    echo "EktosAndGuests: $EktosAndGuests"
    echo "ReliasAndGuests: $ReliasAndGuests"
    echo "Cirkel: $Cirkel"
    echo
    echo
    ((i++))
done
