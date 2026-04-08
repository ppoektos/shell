#!/bin/bash
echo "Starting.."
cd /tmp

cookie=$(curl -kis --stderr - \
--data "ba_username=<ADMIN_USER>&ba_password=<ADMIN_PASSWORD>&goIn=Login" \
https://<HONEYWELL_IP>/web/ | grep Set-Cookie)

cookie=${cookie##*:}
cookie=${cookie%%;*}

curl -ks -o EventReport.csv --cookie "$cookie" \
--data "upload=1&panelNumDnld=1&SelectUploadType=400" \
https://<HONEYWELL_IP>/upload/

last=$(cat /root/scripts/lastEvent)
row=$(grep -n "$last" EventReport.csv | cut -f1 -d:)

declare -a myarray

while read l; do

date=$(echo "$l" | awk -F, '{print $1,$2}' | awk -F"/| " '{print $3"-"$1"-"$2" "$4}')
direction=$(if echo "$l" | grep -q "In"; then echo "In"; else echo "Out"; fi)
user=$(echo "$l" | cut -d"(" -f2 | cut -d")" -f1)

myarray+=("${date},${direction},${user}")

done < <(head -n $(($row-1)) EventReport.csv | \
	 tail -n $(($row-2)) | sed -n '/[()]/p' | tac)

printf '%s\n' "${myarray[@]}" > /var/lib/mysql-files/events.csv

echo "LOAD DATA INFILE '/var/lib/mysql-files/events.csv' \
IGNORE INTO TABLE checkpoint FIELDS TERMINATED BY ',' \
(date,direction,user_id);" | mysql visit

sed -n '2p' EventReport.csv > /root/scripts/lastEvent
mv EventReport.csv /root/scripts/EventReportOld.csv

mysql -e "use visit; \
UPDATE checkpoint SET checkpoint.user_id = \
(SELECT users.id FROM users WHERE users.name = checkpoint.user_id) \
WHERE checkpoint.user_id LIKE '___%' AND checkpoint.user_id !='';"

echo -e "Done! \nReload page to see the date\nof last loaded event above."
