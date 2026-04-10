#!/bin/bash

curlsend () {
curl -s -H "Content-Type: application/xml" -X POST --data "@/root/issue$proj.xml" \
     -H "X-Redmine-API-Key: <REDMINE_API_KEY>" \
     http://<REDMINE_HOST>/issues.xml
}

# find and remove disabled schedule
mysql --login-path=<DB_LOGIN_PATH> -N -B -e "use <REDMINE_DB>; \
SELECT customized_id \
  FROM custom_values \
  WHERE custom_field_id = <FIELD_SCHEDULE> AND value =''" | while read disabled; do
rm -rf /root/issue$disabled.xml /etc/cron.d/proj$disabled
done

# find project, user and schedule, create tasks and cron jobs
mysql --login-path=<DB_LOGIN_PATH> -N -B -e "use <REDMINE_DB>; \
SELECT customized_id as proj_id, value as user_id \
  FROM custom_values \
  WHERE custom_field_id = <FIELD_SCHEDULE> AND value > 2 \
ORDER BY proj_id;" | while IFS=$'\t' read proj user; do

C="curl -s -H \"Content-Type: application/xml\" -X POST --data \"@/root/issue${proj}.xml\" -H \"X-Redmine-API-Key: <REDMINE_API_KEY>\" http://<REDMINE_HOST>/issues.xml"

mysql --login-path=<DB_LOGIN_PATH> -N -B -e "use <REDMINE_DB>; \
SELECT value as schedule \
  FROM custom_values \
  WHERE customized_id = $proj \
AND custom_field_id = <FIELD_USER>;" | while read sch; do

if [ ! -f /etc/cron.d/proj$proj ]; then
cat << EOL > /root/issue$proj.xml
<?xml version="1.0" encoding="ISO-8859-1" ?>
<issue>
  <project_id>$proj</project_id>
  <tracker_id>4</tracker_id>
  <status_id>1</status_id>
  <priority_id>5</priority_id>
  <subject>PM reporting</subject>
  <description>This task is for reporting about project activity before customer.</description>
  <assigned_to_id>$user</assigned_to_id>
</issue>
EOL
case $sch in
  weekly)
        echo "0 9 * * 1 root $C" > /etc/cron.d/proj$proj
  ;;
  fortnightly)
        echo "0 9 * * 1 root test \$((\$(date +\%W)\%2)) -eq 1 && $C" > /etc/cron.d/proj$proj
  ;;
  monthly)
        echo "0 9 1 * * root $C" > /etc/cron.d/proj$proj
  ;;
esac
  curlsend
fi
done
done
