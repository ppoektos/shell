#!/bin/bash
#set -x
cd /opt/notifications || exit 11

Project_name="office1C2 - moving of office1C to H45"

Project_id=$(mysql --login-path=<DB_LOGIN_PATH> -Nse  "use <REDMINE_DB>;
            SELECT projects.id
            FROM projects
            WHERE projects.name LIKE '$Project_name';")

Users=$(mysql --login-path=<DB_LOGIN_PATH> -Nse  "use <REDMINE_DB>;
        SELECT login FROM users, members
        WHERE members.project_id = $Project_id
        AND members.user_id = users.id;")

for user in $Users; do
    Recepients="$user@<NOTIFY_EMAIL>,$Recepients"
done

Recepients=${Recepients%,}

echo "<table style=\"border-collapse: collapse;\" cellpadding=\"5\" border=\"1\">
     <tbody>
     <tr><th>Id</th><th>Priority</th><th>Subject</th><th>Created</th><th>Updated</th>
     <th>Due date</th><th>Status</th><th>Assignee</th></tr>" > office1Cmove.html

while IFS=$'\t' read -r id subject dueto status priority created updated login; do

   # Spent_hours=$(mysql --login-path=<DB_LOGIN_PATH> -Nse  "use <REDMINE_DB>;
   #             SELECT IFNULL(SUM(hours), 0) FROM time_entries
   #             WHERE project_id = $Project_id
   #             AND issue_id = $id
   #             AND spent_on = SUBDATE(CURDATE(),1);")

    Status=$(mysql --login-path=<DB_LOGIN_PATH> -Nse  "use <REDMINE_DB>;
            SELECT name FROM issue_statuses
            WHERE id = $status;")

    if [ "$Status" = New ]; then
        Status="<td style=\"text-align:center\" bgcolor=\"#FF0000\">$Status</td>"
        else
        Status="<td style=\"text-align:center\">$Status</td>"
    fi

    Priority=$(mysql --login-path=<DB_LOGIN_PATH> -Nse  "use <REDMINE_DB>;
            SELECT name FROM enumerations
            WHERE id = $priority;")

    echo "<tr><td style=\"text-align:center\"><a href=\"http://<REDMINE_HOST>/issues/$id\">$id</a></td>
    <td style=\"text-align:center\">$Priority</td>
    <td>$subject</td>
    <td>$created</td>
    <td>$updated</td>
    <td>$dueto</td>
    $Status
    <td style=\"text-align:center\">$login</td></tr>" >> office1Cmove.html

done < <(mysql --login-path=<DB_LOGIN_PATH> -Nse  "use <REDMINE_DB>;
        SELECT issues.id, issues.subject, IFNULL(issues.due_date, 'Not set'),
        issues.status_id, issues.priority_id, issues.created_on, issues.updated_on, users.login
        FROM issues, users
        WHERE issues.project_id = $Project_id
        AND issues.assigned_to_id = users.id
        ORDER BY issues.due_date;")

echo "</table>" >> office1Cmove.html

mutt -e 'set content_type="text/html"' -s "Moving of office1C to H45" -- $Recepients < office1Cmove.html
