#!/bin/bash
grep "<MONTH>/<YEAR>" /root/report/dayperson \
| grep Yes | awk -F, '{print $3}' \
| sed 's/^ \([0-9]\{2\}\)\//\1 /g' \
| awk -F<MONTH>\/<YEAR> '{print $1 $2}' \
| awk -F: '{print $1$2}' > /tmp/orders_month

while read line; do
  arr=($line)
    for (( i=1; i<"${#arr[@]}"; i++ )); do
      echo "Inserting <YEAR>-<MONTH>-${arr[0]} with User:${arr[$i]} to database.."
      echo "INSERT INTO orders (user,order_date) VALUES ('${arr[$i]}', '<YEAR>-<MONTH>-${arr[0]}');" \
| mysql -u <DB_USER> -p<DB_PASSWORD> -h <DB_HOST> lunchorder
    done
echo +++++++++++++++++++++++
done < /tmp/orders_month

echo "UPDATE orders, users SET orders.group_id = '1' WHERE orders.user = users.name and users.group = '1';
UPDATE orders, users SET orders.group_id = '2' WHERE orders.user = users.name and users.group = '2';
UPDATE orders SET orders.group_id = '3' WHERE orders.user NOT IN (SELECT users.name from users);" \
| mysql -u <DB_USER> -p<DB_PASSWORD> -h <DB_HOST> lunchorder
